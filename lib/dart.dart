/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2014 Groboclown
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

library builder.dart;

/**
 * Methods to invoke the commands distributed with the dart sdk.
 */

import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

import 'resource.dart';
import 'tool.dart';
import 'os.dart';
import 'src/logger.dart';

final List<String> DART_PATH = <String>[
    (Platform.environment['DART_SDK'] == null
        ? null
        : Platform.environment['DART_SDK'] + "/bin"),
    (Platform.environment['DART_HOME'] == null
        ? null
        : Platform.environment['DART_HOME'] + "/bin" )];
final String DART_ANALYZER_NAME = "dartanalyzer";


/**
 * Spawns the dartAnalyzer immediately.
 *
 * The [packageRoot] is the package directory.  The returned [Future]
 * executes when the process completes.
 */
Future<Resource> dartAnalyzer(
    Resource dartFile, Project project,
    { DirectoryResource packageRoot: null, String cmd: null,
    Set<String> uniqueLines: null }) {
  if (cmd == null) {
    cmd = DART_ANALYZER_NAME;
  }
  Resource exec = resolveExecutable(cmd, DART_PATH);
  if (exec == null) {
    throw new BuildExecutionException(project.activeTarget,
      "could not find " + cmd);
  }
  
  var args = <String>['--machine', '--show-package-warnings'];
  if (packageRoot != null) {
    args.add('--package-root');
    args.add(packageRoot.fullName);
  }
  args.add(dartFile.fullName);

  project.logger.debug("Running [" + exec.fullName + "] with arguments " +
    args.toString());
  return processStartSync(exec.fullName, args, (process) {
    // add stdout and stderr into a single stream
    process.stderr.transform(createCsvTransformer(uniqueLines))
      .listen((List<String> row) {
        if (row.length >= 8) {
          var msg = new LogMessage.resource(
              level: row[0].toLowerCase(),
              tool: "dartanalyzer",
              category: row[1],
              id: row[2],
              file: new FileResource(new File(row[3])),
              line: int.parse(row[4]),
              charStart: int.parse(row[5]),
              charEnd: int.parse(row[5]) + int.parse(row[6]),
              message: row[7]
          );
          project.logger.message(msg);
        }
      });
    process.stdout.transform(new LineSplitter()).listen((String data) {
      project.logger.fileInfo(tool: "dartanalyzer",
          file: dartFile, message: data);
    });
  }).then((code) {
    project.logger.info("Completed processing " + dartFile.name);
  }).then((_) => dartFile);
}


class DartAnalyzer extends BuildTool {
  final String cmd;
  final DirectoryResource packageRoot;

  factory DartAnalyzer(String name,
      { String description: "", String phase: PHASE_BUILD,
        ResourceCollection dartFiles: null, List<String> depends: null,
        DirectoryResource packageRoot: null,
        String cmd: null }) {
    if (depends == null) {
      depends = <String>[];
    }
    
    var pipe = new Pipe.list(dartFiles.entries(), <Resource>[]);
    var targetDef = BuildTool
      .mkTargetDef(name, description, phase, pipe, depends, <String>[]);
    return new DartAnalyzer._(name, targetDef, phase, pipe, cmd, packageRoot);
  }


  DartAnalyzer._(String name, target targetDef, String phase, Pipe pipe,
    String cmd, DirectoryResource packageRoot) :
    this.cmd = cmd, this.packageRoot = packageRoot,
    super(name, targetDef, phase, pipe);


  @override
  Future<Project> start(Project project) {
    var inp = new List<Resource>.from(pipe.requiredInput);
    inp.addAll(pipe.optionalInput);

    if (inp.isEmpty) {
      project.logger.info("nothing to do");
      return new Future<Project>.sync(() => project);
    }

    var uniqueLines = new Set<String>();

    // Chain the calls, rather than running in parallel.
    // For running in parallel, we create all the Futures in the
    // calls to dartAnalyzer, then return a Future.wait() on all of them.
    var runList = new Sequential<Resource>(
      inp.map((r) {
        Future<Resource> ret() {
          if (r.exists && ! (r is ResourceListable)) {
            return dartAnalyzer(r, project,
              packageRoot: packageRoot, cmd: cmd,
              uniqueLines: uniqueLines);
          } else {
            return new Future<Resource>.sync(() => r);
          }
        }
        return new FutureFactory<Resource>(ret);
      })
    );
    return runList.call().drain().then((_) => project);
  }
}


StreamTransformer<String, List<String>> createCsvTransformer(
    [ Set<String> uniqueLines ]) {
  var leftover = new StringBuffer();
  var state = 0;
  var currentRow = <String>[];

  void sinkUniqueRow(sink, row) {
    if (uniqueLines != null) {
      var r = new StringBuffer();
      r.writeAll(row, "|");
      var s = r.toString();
      if (uniqueLines.contains(s)) {
        return;
      }
      uniqueLines.add(s);
    }
    sink.add(new List<String>.from(row));
  }

  return new StreamTransformer<String, List<String>>.fromHandlers(
      handleData: (value, sink) {
        //print("**" + value.toString());
        if (value != null) {
          for (var p = 0; p < value.length; ++p) {
            var c = new String.fromCharCode(value[p]);
            switch (state) {
              case 0: // normal inside cell
                if (c == '\\') {
                  state = 1;
                } else if (c == '|') {
                  // end of cell
                  currentRow.add(leftover.toString());
                  leftover.clear();
                } else if (c == '\r' || c == '\n') {
                  // end of row and cell
                  if (currentRow.isNotEmpty || leftover.isNotEmpty) {
                    currentRow.add(leftover.toString());
                  }
                  leftover.clear();
                  if (currentRow.isNotEmpty) {
                    sinkUniqueRow(sink, currentRow);
                  }
                  currentRow.clear();
                  state = 2;
                } else {
                  leftover.write(c);
                }
                break;
              case 1: // escape
                if (c == 'n') {
                  leftover.write("\n");
                } else if (c == 'r') {
                  leftover.write("\r");
                } else if (c == 't') {
                  leftover.write("\t");
                } else {
                  leftover.write(c);
                }
                state = 0;
                break;
              case 2: // end of row
                if (c != '\n' && c != '\r') {
                  leftover.write(c);
                  state = 0;
                }
                break;
              default:
                throw new Exception("invalid state: " + state.toString());
            }
          }
        }
      },
    handleDone: (sink) {
      if (leftover.isNotEmpty) {
        currentRow.add(leftover.toString());
      }
      if (currentRow.isNotEmpty) {
        sinkUniqueRow(sink, currentRow);
      }
    });
}





Future runAsUnitTest(Resource dartFile, Project project,
    [ List<String> testArgs ]) {
  if (testArgs == null) {
    testArgs = <String>[];
  }
  var response = new ReceivePort();
  Future<Isolate> remote = Isolate.spawnUri(Uri.parse(dartFile.fullName),
    testArgs, response.sendPort);

  return remote.then((p) => response.forEach((msg) {
      project.logger.message(msg);
    }));
}


