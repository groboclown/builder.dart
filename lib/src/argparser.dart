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


library builder.src.argparser;

import 'dart:io';
import 'package:args/args.dart';
import 'target.dart';
import 'logger.dart';

/**
 * Parsed build arguments.  Based upon the build.dart standard
 * https://www.dartlang.org/tools/editor/build.html
 * plus additional arguments for custom targets.
 */
class BuildArgs {
  final Logger logger;

  /**
   * All the targets supported by the build file.
   */
  final List<TargetMethod> allTargets;

  /**
   * All the targets explicitly or implicitly invoked from the command line.
   */
  final List<TargetMethod> calledTargets;

  final List<String> changed;
  final List<String> removed;



  /**
   * Performs an exit call if the args are not valid.
   */
  factory BuildArgs.fromCmd(List<String> args,
      List<TargetMethod> supportedTargets,
      { void usageCallback(ArgParser parser) } ) {
    var res = _parseArgs(args, supportedTargets, usageCallback);
    var targets = <TargetMethod>[];
    for (var tgt in supportedTargets) {
      if (res[tgt.name]) {
        targets.add(tgt);
      }
    }

    if (targets.isEmpty) {
      targets.addAll(supportedTargets.where((t) => t.targetDef.isDefault));
    }

    Logger logger;
    if (res['machine']) {
      logger = new JsonLogger();
    } else {
      logger = new CmdLogger();
    }

    return new BuildArgs(logger, supportedTargets, targets, res['changed'],
      res['removed']);
  }

  BuildArgs(this.logger, this.allTargets, this.calledTargets,
      this.changed, this.removed);

}


/**
 * Performs an exit call if the args are not valid.
 */
ArgResults _parseArgs(List<String> args, List<TargetMethod> supportedTargets,
    void usageCallback(ArgParser parser)) {
  if (args == null) {
    args = [];
  }
  if (usageCallback == null) {
    usageCallback = _showUsage;
  }
  var parser = new ArgParser()
    ..addOption("changed",
      help: "Specifies a file that changed and should be rebuilt.",
      allowMultiple: true)
    ..addOption("removed",
      help: "Specifies a file that was removed and might affect the build.",
      allowMultiple: true)
    ..addFlag("machine",
      help: "Print rich JSON error messages to the standard output (stdout)")
    ..addFlag("help",
      help: "This help message",
      negatable: false);

  supportedTargets.forEach((k) => parser.addFlag(k.name, help: k.description,
    negatable: false));

  var res;
  try {
    res = parser.parse(args);
  } on FormatException catch (e) {
    print(e.message);
    usageCallback(parser);
    exit(1);
  }

  if (res['help']) {
    usageCallback(parser);
    exit(0);
  }
  return res;
}

void _showUsage(ArgParser parser) {
  print("Build script for this Dart project.");
  print("Usage: dart build.dart [options] [targets]");
  print(parser.getUsage());
}
