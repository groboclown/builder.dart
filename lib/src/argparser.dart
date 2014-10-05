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

import 'targetmethod.dart';
import 'logger.dart';

/**
 * Parsed build arguments.  Based upon the build.dart standard
 * https://www.dartlang.org/tools/editor/build.html
 * plus additional arguments for custom targets.
 */
class BuildArgs {
  final AbstractLogger logger;

  /**
   * All the targets supported by the build file.
   */
  final Iterable<TargetMethod> allTargets;

  /**
   * All the targets explicitly or implicitly invoked from the command line.
   */
  final Iterable<TargetMethod> calledTargets;
  final Iterable<TargetMethod> defaultTargets;

  final List<String> changed;
  final List<String> removed;

  /**
   * Directory of settings used for this project's build temporary objects.
   * If `null`, then no temporary build files will be used.
   *
   */
  String buildTempDir;



  /**
   * Performs an exit call if the args are not valid.
   */
  factory BuildArgs.fromCmd(Iterable<String> args,
      Iterable<TargetMethod> supportedTargets,
      { void usageCallback(ArgParser parser) } ) {
    ArgResults res = _parseArgs(args, supportedTargets, usageCallback);
    var targets = <TargetMethod>[];
    for (var tgt in supportedTargets) {
      if (res[tgt.name]) {
        targets.add(tgt);
      }
    }
    for (var r in res.rest) {
      bool found = false;
      for (var tgt in supportedTargets) {
        if (tgt.name == r) {
          found = true;
          targets.add(tgt);
        }
      }
      if (! found) {
        print("Unknown build target '${r}'.  Use '--help' to find the build targets available.");
        exit(1);
      }
    }


    var defaultTargets = supportedTargets.where(
        (t) => t.targetDef.isDefault);

    AbstractLogger logger;
    if (res['machine']) {
      logger = new JsonLogger();
    } else {
      logger = new CmdLogger(res['color']);
    }

    List<String> changed = res['changed'];
    if (changed == null) {
      changed = <String>[];
    }
    List<String> removed = res['removed'];
    if (removed == null) {
      removed = <String>[];
    }

    return new BuildArgs(logger, supportedTargets, targets, changed,
      removed, defaultTargets,
      // FIXME set this to a better value
      null);
  }

  BuildArgs(this.logger, this.allTargets, this.calledTargets,
      this.changed, this.removed, this.defaultTargets, this.buildTempDir);


  Iterable<TargetMethod> get targetsToRun =>
    calledTargets.isEmpty ? defaultTargets : calledTargets;


  /**
   * Sets the temporary directory as defined by the project.  This will override
   * environment settings (because the build file declared its preferred
   * location), but will not override explicit user definitions for the
   * directory.
   */
  void setProjectTempDir(String tempDir) {
    // For now, because we don't support user overrides or environment
    // defaults, we just use this value.
    buildTempDir = tempDir;
  }
}


/**
 * Performs an exit call if the args are not valid.
 */
ArgResults _parseArgs(Iterable<String> args,
    Iterable<TargetMethod> supportedTargets,
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
    ..addFlag("color",
      help: "Force display in color mode", defaultsTo: null)
    ..addFlag("help",
      help: "This help message",
      negatable: false);

  supportedTargets.forEach((k) =>
    parser.addFlag(k.name, help: "Run target " + k.targetDef.description,
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
