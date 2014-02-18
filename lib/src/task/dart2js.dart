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


/**
 * Executes the `dart2js` command in a separate process.
 */
library builder.src.task.dart2js;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../../task.dart';
import '../dart_path.dart';
import '../os.dart';


Future dart2js(Resource dartFile, Logger logger,
    StreamController<LogMessage> messages,
    { TargetMethod activeTarget, Resource outputFile, String cmd: null,
    bool checked: true, bool minified: false }) {
  assert(messages != null);
  assert(dartFile != null);
  if (cmd == null) {
    cmd = DART2JS_NAME;
  }
  Resource exec = resolveExecutable(cmd, DART_PATH);
  if (exec == null) {
    throw new BuildExecutionException(activeTarget,
      "could not find " + cmd);
  }

  var args = <String>[];
  if (checked) {
    args.add("-c");
  }
  if (minified) {
    args.add("-m");
  }
  if (outputFile != null) {
    args
      ..add("-o")
      ..add(outputFile.absolute);
  }
  args.add(dartFile.relname);

  logger.debug("Running [" + exec.relname + "] with arguments " +
  args.toString());

  return Process.start(exec.relname, args).then((process) {
    process.stderr.transform(new LineSplitter()).listen((String line) {
      // TODO process the output data.
      logger.warn(line);
    });
    process.stdout.transform(new LineSplitter()).listen((String data) {
      // TODO process the output data.
      logger.info(data);
    });
    return process.exitCode;
  }).then((code) {
    logger.fileInfo(
        tool: "dart2js",
        file: dartFile,
        message: "Completed processing " + dartFile.name);
    return new Future.value(code);
  });
}

