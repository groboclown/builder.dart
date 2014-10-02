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


library builder.src.task.dartanalysis;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../dart_path.dart';

import '../../task.dart';
import '../os.dart';

/**
 * Spawns the dartAnalyzer immediately.
 *
 * The [packageRoot] is the package directory.  The returned [Future]
 * executes when the process completes.
 */
Future dartAnalyzer(
    Resource dartFile, Logger logger, StreamController<LogMessage> messages,
    { DirectoryResource packageRoot: null, String cmd: null,
    Set<String> uniqueLines: null, TargetMethod activeTarget: null }) {
  assert(messages != null);
  assert(dartFile != null);
  if (cmd == null) {
    cmd = DART_ANALYZER_NAME;
  }
  Resource exec = resolveExecutable(cmd, DART_PATH);
  if (exec == null) {
    throw new BuildExecutionException(activeTarget,
      "could not find " + cmd);
  }

  var args = <String>['--machine', '--show-package-warnings'];
  if (packageRoot != null) {
    args.add('--package-root');
    args.add(packageRoot.relname);
  }
  args.add(dartFile.relname);

  logger.debug("Running [" + exec.relname + "] with arguments " +
  args.toString());

  return Process.start(exec.relname, args).then((Process process) {
    // stderr: real output data to process
    process.stderr.transform(new Utf8Decoder()).transform(
            _createCsvTransformer(uniqueLines))
      .listen((List<String> row) {
        if (row.length >= 8) {
          var msg = new LogMessage.resource(
              level: row[0].toLowerCase(),
              tool: "dartanalyzer",
              category: row[1],
              id: row[2],
              file: new FileEntityResource.fromEntity(new File(row[3])),
              line: int.parse(row[4]),
              charStart: int.parse(row[5]),
              charEnd: int.parse(row[5]) + int.parse(row[6]),
              message: row[7]
          );
          messages.add(msg);
          logger.message(msg);
        }
      });
    // stdout: logging information
    process.stdout.transform(new Utf8Decoder()).transform(new LineSplitter())
        .listen((String data) {
          logger.fileInfo(tool: "dartanalyzer",
          file: dartFile, message: data);
        });
    return process.exitCode;
  }).then((code) {
    logger.fileInfo(
        tool: "dartanalysis",
        file: dartFile,
        message: "Completed processing " + dartFile.name);
    return new Future.value(0);
  });
}






StreamTransformer<String, List<String>> _createCsvTransformer(
    [ Set<String> uniqueLines ]) {
  var leftover = new StringBuffer();
  var state = 0;
  var currentRow = <String>[];

  void sinkUniqueRow(EventSink<List<String>> sink, List<String> row) {
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
      handleData: (String value, EventSink<List<String>> sink) {
        //print("**" + value.toString());
        if (value != null) {
          for (var p = 0; p < value.length; ++p) {
            var c = value[p];
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
      handleDone: (EventSink<List<String>> sink) {
        if (leftover.isNotEmpty) {
          currentRow.add(leftover.toString());
        }
        if (currentRow.isNotEmpty) {
          sinkUniqueRow(sink, currentRow);
        }
      });
}
