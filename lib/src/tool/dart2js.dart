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


library builder.src.tool.dart2js;


/**
 * Executes the `dart2js` command in a separate process.
 */

import 'dart:async';

import '../../tool.dart';
import '../task/dart2js.dart';

/**
 * Build tool for running the `dart2js` tool on a set of input files.
 * It takes the following arguments, in addition to the normal build tool
 * arguments:
 *
 * * `cmd` ([String]) - the actual command to run.  By default, this is
 *  found using the `DART_HOME` or `DART_SDK` environment variable, under
 *  the `bin/dartanalyzer` name.
 * * `dartFiles` ([ResourceSet]) - all the files to analyze.  For each file
 *  in this set, the analyzer will be called once.  This most probably will
 *  cause the analyzer to check the same file multiple times, so you can
 *  optimize your build to just include the entry files.  For safety, this
 *  can just be every dart file, but will run slower.
 * * `onFailure` ([FailureMode]) - how to handle a failure message from the
 *  analyzer.  Default is to quit the build with an error.
 */

class Dart2JS extends BuildTool {
  final String cmd;

  final FailureMode onFailure;

  final bool minified;

  final bool checked;

  factory Dart2JS(String name,
      { String description: "", String phase: PHASE_BUILD,
      ResourceCollection dartFiles: null, List<String> depends: null,
      bool minified: false, bool checked: true, DirectoryResource outdir: null,
      String cmd: null, FailureMode onFailure: null }) {
    if (depends == null) {
      depends = <String>[];
    }

    if (outdir == null) {
      throw new BuildSetupException("outdir was not set");
    }

    // FIXME this needs a better mapping.  Perhaps user-defined via the
    // Relation classes?
    var direct = <Resource, List<Resource>>{};
    for (var f in dartFiles.entries()) {
      if (f is ResourceStreamable) {
        direct[f] = <Resource>[ outdir.child(f.name + ".js", 'file') ];
      }
    }

    var pipe = new Pipe.direct(direct);
    var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
    depends, <String>[]);
    return new Dart2JS._(name, targetDef, phase, pipe, minified, checked,
      cmd, onFailure);
  }


  Dart2JS._(String name, TargetDef targetDef, String phase, Pipe pipe,
      bool minified, bool checked, String cmd, FailureMode onFailure) :
    this.minified = minified,
    this.checked = checked,
    this.cmd = cmd,
    this.onFailure = onFailure,
    super(name, targetDef, phase, pipe);


  @override
  Future<Project> start(Project project) {
    var inp = getChangedInputs();

    if (inp.isEmpty) {
      project.logger.info("nothing to do");
      return new Future<Project>.sync(() => project);
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
        var out = pipe.directPipe[r].single;
        Future next(_) {
          return dart2js(r, project.logger, messages,
              cmd: cmd, outputFile: out,
              minified: minified, checked: checked,
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
        failureMessage: "one or more files had errors");
      }
      return new Future<Project>.sync(() => project);
    });
    return ret;
  }
}

