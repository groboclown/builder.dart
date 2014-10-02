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

library builder.src.tool.mkdir;

/**
 * Standard build constants for the normal dart project layout, based on
 * (package layout conventions)[http://pub.dartlang.org/doc/package-layout.html].
 */

import '../../tool.dart';

import 'dart:io';
import 'dart:async';


/**
 * For the most part, this is automatically performed.  However, there are some
 * circumstances where the build requires the creation of an empty directory.
 */
class MkDir extends BuildTool {
  final FailureMode onFailure;

  factory MkDir(String name,
                 { String description: "", String phase: PHASE_BUILD,
                 Resource dir: null, List<String> depends: null,
                 FailureMode onFailure: null }) {
    if (depends == null) {
      depends = <String>[];
    }

    // This generates a resource without any input
    var pipe = new Pipe.list(null, <Resource>[ dir ]);
    var targetDef = BuildTool
      .mkTargetDef(name, description, phase, pipe, depends, <String>[]);
    return new MkDir._(name, targetDef, phase, pipe, onFailure);
  }


  MkDir._(String name, TargetDef targetDef, String phase, Pipe pipe,
           FailureMode onFailure) :
    this.onFailure = onFailure,
    super(name, targetDef, phase, pipe);


  @override
  Future start(Project project) {
    var out = pipe.output;
    if (out.isEmpty) {
      project.logger.info("nothing to do");
      return null;
    }

    var problems = <Resource>[];
    Future ret = new Future.value(null);
    for (Resource r in out) {
      if (! r.exists && r is DirectoryResource) {
        ret = ret.then((_) => (r.entity as Directory).create(recursive: true).
            catchError((error, stack) {
              project.logger.fileException(file: r, exception: error,
                stackTrace: stack);
              problems.add(r);
            }));
      }
    }

    return ret.then((_) {
      if (problems.isNotEmpty) {
        handleFailure(project,
          mode: onFailure,
          failureMessage: "could not create the following directories: " +
            problems.toString());
      }
    });
  }
}

