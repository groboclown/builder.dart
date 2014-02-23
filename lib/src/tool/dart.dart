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


library builder.src.tool.dart;


/**
 * Executes the `dart` command in a separate process.
 */

import 'dart:async';

import '../../tool.dart';
import '../task/dart.dart';

/**
 * Build tool for running the `dart` command.
 */
class Dart extends BuildTool {
  final String cmd;

  final FailureMode onFailure;

  final bool checked;

  factory Dart(String name,
      { String description: "", String phase: PHASE_BUILD,
      ResourceStreamable dartFile: null, List<String> depends: null,
      bool checked: true, String cmd: null, FailureMode onFailure: null }) {
    if (depends == null) {
      depends = <String>[];
    }

    var pipe = new Pipe.single(dartFile, null);
    var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
      depends, <String>[]);
    return new Dart._(name, targetDef, phase, pipe, checked, cmd, onFailure);
  }


  Dart._(String name, TargetDef targetDef, String phase, Pipe pipe,
      bool checked, String cmd, FailureMode onFailure) :
    this.checked = checked,
    this.cmd = cmd,
    this.onFailure = onFailure,
    super(name, targetDef, phase, pipe);


  @override
  Future start(Project project) {
    var inp = getChangedInputs();

    if (inp.isEmpty) {
      project.logger.info("nothing to do");
      return null;
    }

    var hadErrors = false;

    StreamController<LogMessage> messages = new StreamController<LogMessage>();
    messages.stream.listen((LogMessage msg) {
      if (msg.level.startsWith("err")) {
        hadErrors = true;
      }
    });

    // Chain the calls, rather than running in parallel.
    Future ret = null;
    for (Resource r in inp) {
      if (r.exists && r is ResourceStreamable) {
        Future next(_) {
          return dart(r, project.logger, messages,
              cmd: cmd, checked: checked,
              activeTarget: project.activeTarget)
            .then((code) {
              if (code != 0) {
                hadErrors = true;
              }
            });
        }
        if (ret == null) {
          ret = next(project);
        }
        else {
          ret = ret.then(next);
        }
      }
    }
    ret = ret.then((_) {
      messages.close();
      if (hadErrors) {
        handleFailure(project,
        mode: onFailure,
        failureMessage: "execution of " + inp[0] + " failed");
      }
    });
    return ret;
  }
}
