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

import 'dart:io';
import 'dart:convert';

import 'resource.dart';
import 'tool.dart';

/**
 * Methods to invoke the commands distributed with the dart sdk.
 */


final Directory DART_HOME = new Directory(Platform.environment['DART_HOME']);
final Directory DART_BIN = new Directory(DART_HOME.path + "/bin");
final File DART_ANALYZER_EXEC = new File(DART_BIN.path + "/dartanalyzer");


/**
 * The `packageRoot` is the root directory of the project being built.  It
 * should contain a `packages` directory.
 */
List<LogMessage> dartAnalyzer(FileResource packageRoot,
    Resource dartFile, { File cmd: DART_ANALYZER_EXEC }) {
  var args = <String>['--machine', '--show-package-warnings', '--package-root',
    packageRoot.fullName];
  args.add(dartFile.fullName);

  ProcessResult result = Process.runSync(cmd.path, args);

  var ret = <DartAnalyzerResult>[];
  for (List<String> line in _csvParser(result.stdout)) {
    // Don't know what column 6 is for.  It's an int.  Might be the message id.
    var msg = new LogMessage.resource(
      level: line[0].toLowerCase(),
      tool: "dartanalyzer",
      catgegory: line[1],
      id: line[2],
      file: new FileResource(new File(line[3])),
      line: int.parse(line[4]),
      charStart: int.parse(line[5]),
      charEnd: int.parse(line[6]),
      message: line[7]
    );
    ret.add(msg);
  }
  return ret;
}


class DartAnalyzer extends BuildTool {
  final File cmd;
  final Directory packageRoot;

  factory DartAnalyzer(String name,
      { String description: "", String phase: PHASE_BUILD,
        ResourceCollection dartFiles: null, List<String> depends: <String>[],
        // FIXME use the correct "current directory" call
        DirectoryResource packageRoot: new DirectoryResource("."),
        File cmd: DART_ANALYZER_EXEC }) {
    var pipe = new Pipe.list(dartFiles.entries(), <Resource>[]);
    var targetDef = mkTargetDef(name, description, pipe, depends, <String>[]);
    
    // DEBUG
    print("Creating DartAnalyzer target " + name);
    
    return new DataAnalyzer._(name, targetDef, phase, pipe, cmd, packageRoot);
  }


  DartAnalyzer._(String name, target targetDef, String phase, Pipe pipe,
    File cmd, Directory packageRoot) :
    this.cmd = cmd, this.packageRoot = packageRoot,
    super(name, targetDef, phase, pipe);


  @override
  void call(Project project) {
    List<Resource> inp = new List<Resource>.from(pipe.requiredInput);
    inp.addAll(pipe.optionalInput);
    for (Resource r in inp) {
      if (r.exists && ! r.isDirectory) {
        dartAnalyzer(packageRoot, r, cmd: cmd)
          .forEach((m) => project.logger.message(m));
      }
    }
  }
}





List<List<String>> _csvParser(String data) {
  var splitter = new LineSplitter();
  var ret = <List<String>>[];
  // FIXME This isn't right - need to unescape newlines that could join a cell
  for (String line in splitter.convert(data)) {
    var row = <String>[];
    for (String cell in line.split('|')) {
      row.add(cell.replaceAll(new RegExp(r'\\\\'), '\\'));
    }
  }
  return ret;
}
