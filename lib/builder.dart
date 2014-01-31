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

library builder;

import 'src/argparser.dart';
import 'src/project.dart';

import 'src/decl.dart' as decl;
export 'src/decl.dart' show VirtualTarget;

import 'tool.dart' as tool;
export 'tool.dart' show
    Pipe, BuildTool, addPhase, getTargets,
    PHASE_CLEAN, PHASE_BUILD, PHASE_ASSEMBLE, PHASE_DEPLOY;
export 'resource.dart';


/**
 * The declarative build tool.
 *
 * With the `builder` library, the build script declares the different outputs
 * that it generates, and the different additional tasks that it runs.
 *
 * Each tool declares the phase that it runs in, and a [Pipe] of inputs and
 * outputs.
 *
 * Phases are just targets that have dependencies on themselves in a pre-defined
 * order.  By default, the build defines the phases "clean", "build",
 * "assemble", and "deploy".  Tests are either part of the deploy phase
 * (for client-side tests) or the build phase (unit tests).  Additional phases
 * can be added with the [addPhase()] call.  Additionally, the phases
 * have the "default" target setting, not the tools.
 */



void build(List<String> args, { libraryName: "build" }) {
  var buildArgs = new BuildArgs.fromCmd(args,
    tool.getTargets(libraryName: libraryName));
  var project = new Project.parse(buildArgs);
  var changedTargets = decl.computeChanges(project);
  if (buildArgs.calledTargets.isEmpty && changedTargets.isEmpty) {
    // TODO see if this should be the "default" target instead.
    project.buildTargets( <tool.TargetMethod>[ tool.TARGET_NOOP ] );
  } else if (buildArgs.calledTargets.isEmpty) {
    project.buildTargets(changedTargets);
  } else {
    project.buildTargets(buildArgs.calledTargets);
  }
}


