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

library builder.src.tool.delete;

/**
 * Standard build constants for the normal dart project layout, based on
 * (package layout conventions)[http://pub.dartlang.org/doc/package-layout.html].
 */

import '../../tool.dart';

import 'dart:async';


/**
 *
 */
class Delete extends BuildTool {
  final ResourceCollection _files;
  final FailureMode onFailure;

  factory Delete(String name,
      { String description: "", String phase: PHASE_CLEAN,
      ResourceCollection files: null, List<String> depends: null,
      FailureMode onFailure: null }) {
    if (depends == null) {
      depends = <String>[];
    }

    // Because this is a Clean, this does not really take files as input.
    var pipe = new Pipe.list(null, null);
    var targetDef = BuildTool
      .mkTargetDef(name, description, phase, pipe, depends, <String>[]);
    return new Delete._(name, targetDef, phase, pipe, files, onFailure);

  }


  Delete._(String name, target targetDef, String phase, Pipe pipe,
      ResourceCollection files, FailureMode onFailure) :
      this._files = files, this.onFailure = onFailure,
      super(name, targetDef, phase, pipe);


  @override
  Future<Project> start(Project project) {
    var inp = _files.entries();
    if (inp.isEmpty) {
      project.logger.info("nothing to do");
      return new Future<Project>.sync(() => project);
    }

    return new Future<Project>.sync(() {
      var problems = <Resource>[];
      for (Resource r in inp) {
        if (r.exists) {
          if (! r.delete(false)) {
            problems.add(r);
          }
        }
      }
      if (problems.isNotEmpty) {
        handleFailure(project,
          mode: onFailure,
          failureMessage: "could not remove the following files: " +
            problems.toString());
      }
      return new Future<Project>.sync(() => project);
    });
  }
}

