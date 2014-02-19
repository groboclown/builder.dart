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

library build;

/**
 * An example build showing how to use the Exec build tool.
 */

// The build library
import '../../lib/builder.dart';

// The standard package layout definitions
import '../../lib/std.dart';

// The custom tool library
import '../../lib/tool.dart';

import 'dart:async';
import 'dart:convert';

// The tools to run

final checkForFixmes = new NoFixmesTool("fixme",
  description: "check for fixme strings in files",
  files: new FileEntityResource.asDir(".").asCollection(
      resourceTest: DART_FILE_FILTER, recurseTest: SOURCE_RECURSION_TEST));


// The primary build

void main(List<String> args) {
// Run the build
  build(args);
}



class NoFixmesTool extends BuildTool {
  final FailureMode onFailure;

  factory NoFixmesTool(String name, {
      String description: "", String phase: PHASE_BUILD,
      List<String> depends: null,
      ResourceCollection files, FailureMode onFailure: null }) {

    var pipe = new Pipe.list(files.entries(), <Resource>[]);
    var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
      depends, <String>[]);
    return new NoFixmesTool._(name, targetDef, phase, pipe, onFailure);
  }


  NoFixmesTool._(String name, TargetDef targetDef, String phase, Pipe pipe,
      FailureMode onFailure) :
    this.onFailure = onFailure,
    super(name, targetDef, phase, pipe);


  @override
  Future<Project> start(Project project) {
    var ret = new Future<Project>(() => project);
    var waiters = <Future>[];
    //var lineno = <Resource, int>{};
    var errors = 0;
    for (Resource r in getChangedInputs()) {
      if (r.exists && r.readable) {
        var c = new Completer();
        try {
          var s = r.openRead();
          var line = 0;
          s.transform(new LineSplitter()).listen((String data) {
            line++;
            var col = (data == null) ? -1 : data.indexOf("FIXME") >= 0;
            if (col >= 0) {
              errors++;
              project.logger.message(new LogMessage.resource(level: ERROR,
                tool: "fixme-finder",
                file: r, line: line, charStart: col, charEnd: col + 5,
                message: "found 'FIXME'"));
            }
          }, onDone: () {
            c.complete();
          }, onError: (e, s) {
            c.completeError(e, s);
          });
        } catch (e, s) {
          completer.completeError(e, s);
        }
        waiters.add(c.future);
      }
    }
    return Future.wait(waiters).then((_) {
      if (errors > 0) {
        handleFailure(project,
          mode: onFailure,
          failureMessage: "one or more files had errors");
      }
      return ret;
    });
  }
}

