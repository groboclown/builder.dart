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
 * The [packageRoot] is the package directory.
 */
List<LogMessage> dartAnalyzer(
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
  ProcessResult result = Process.runSync(exec.fullName, args);

  var ret = <LogMessage>[];
  for (List<String> line in _csvParser(
      result.stdout + "\n" + result.stderr, uniqueLines)) {
    if (line.length >= 8) {
      // Don't know what column 6 is for.  It's an int.  Might be the message id.
      var msg = new LogMessage.resource(
        level: line[0].toLowerCase(),
        tool: "dartanalyzer",
        category: line[1],
        id: line[2],
        file: new FileResource(new File(line[3])),
        line: int.parse(line[4]),
        charStart: int.parse(line[5]),
        charEnd: int.parse(line[5]) + int.parse(line[6]),
        message: line[7]
      );
      ret.add(msg);
    } else {
      ret.add(new LogMessage.tool(level: ERROR, tool: "dartanalyzer",
        message: line.toString()));
    }
  }
  return ret;
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
  void call(Project project) {
    var inp = new List<Resource>.from(pipe.requiredInput);
    inp.addAll(pipe.optionalInput);
    var uniqueLines = new Set<String>();
    for (Resource r in inp) {
      if (r.exists && ! (r is ResourceListable)) {
        project.logger.info("Processing " + r.name);
        dartAnalyzer(r, project, packageRoot: packageRoot, cmd: cmd,
            uniqueLines: uniqueLines)
          .forEach((m) => project.logger.message(m));
      } else {
        project.logger.debug("Skipping " + r.name);
      }
    }
  }
}





List<List<String>> _csvParser(String data, Set<String> uniqueLines) {
  var splitter = new LineSplitter();
  var ret = <List<String>>[];
  // FIXME This isn't right - need to unescape newlines that could join a cell
  for (String line in splitter.convert(data)) {
    if (! line.isEmpty &&
        (uniqueLines == null || ! uniqueLines.contains(line))) {
      if (uniqueLines != null) {
        uniqueLines.add(line);
      }
      var row = <String>[];
      for (String cell in line.split('|')) {
        row.add(cell.replaceAll(new RegExp(r'\\\\'), '\\'));
      }
      ret.add(row);
    }
  }
  return ret;
}



List<LogMessage> runAsUnitTest(Resource dartFile, Project project) {

}


