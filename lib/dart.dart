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
import 'src/tool.dart';
import 'src/logger.dart';

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
List<DartAnalyzerResult> dartAnalyzer(FileResource packageRoot,
    ResourceCollection resources) {
  var args = <String>['--machine', '--show-package-warnings', '--package-root',
    packageRoot.fullName];
  for (Resource r in resources.entries()) {
    args.add(r.fullName);
  }


  ProcessResult result = Process.runSync(DART_ANALYZER_EXEC.path, args);

  var ret = <DartAnalyzerResult>[];
  for (List<String> line in _csvParser(result.stdout)) {
    // Don't know what column 6 is for.  It's an int.  Might be the message id.
    ret.add(new DartAnalyzerResult(
      line[0], line[1], line[2], new FileResource(new File(line[3])),
      int.parse(line[4]), int.parse(line[5]), line[7]));
  }
}


class DartAnalyzer extends BuildTool {

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
