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
 * The declarative build tool library.
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

library builder.tool;

// Make a few private items publicly available.

//import 'src/exceptions.dart';
export 'src/exceptions.dart' show
  // Only export the top-level exceptions.
  BuildException, BuildSetupException, BuildExecutionException;

import 'src/decl.dart' as decl;
export 'src/decl.dart' show
  BuildTool, Pipe, addPhase;

//import 'src/logger.dart';
export 'src/logger.dart' show
  Logger, LogMessage;

//import 'src/project.dart';
export 'src/project.dart' show
  Project;

import 'src/target.dart';
export 'src/target.dart' show
  TargetMethod, target;

const String TARGET_CLEAN = "clean";
const String TARGET_BUILD = "build";
const String TARGET_ASSEMBLE = "assemble";
const String TARGET_DEPLOY = "deploy";


const String PHASE_CLEAN = "phase_clean";
const String PHASE_BUILD = "phase_build";
const String PHASE_ASSEMBLE = "phase_assemble";
const String PHASE_DEPLOY = "phase_deploy";




final TargetMethod TARGET_PHASE_CLEAN = decl.addPhase(
    PHASE_CLEAN, TARGET_CLEAN,
    <String>[ PHASE_BUILD, PHASE_ASSEMBLE, PHASE_DEPLOY ],
    <String>[]);
final TargetMethod TARGET_PHASE_BUILD = decl.addPhase(
    PHASE_BUILD, TARGET_BUILD,
    <String>[ PHASE_ASSEMBLE, PHASE_DEPLOY ],
    <String>[ PHASE_CLEAN ],
    isDefault: true);
final TargetMethod TARGET_PHASE_ASSEMBLE = decl.addPhase(
    PHASE_ASSEMBLE, TARGET_ASSEMBLE,
    <String>[ PHASE_DEPLOY ],
    <String>[ PHASE_CLEAN, PHASE_BUILD ]);
final TargetMethod TARGET_PHASE_DEPLOY = decl.addPhase(
    PHASE_DEPLOY, TARGET_DEPLOY,
    <String>[],
    <String>[ PHASE_CLEAN, PHASE_BUILD, PHASE_ASSEMBLE ]);
final TargetMethod TARGET_FULL = new decl.VirtualTarget(
    "full", "the complete build",
    <String>[ TARGET_CLEAN, TARGET_BUILD, TARGET_ASSEMBLE, TARGET_DEPLOY ],
    <String>[], true);


List<TargetMethod> getTargets({ libraryName: "build" }) {
  // Ensure the default top-level phases exist (avoiding the lazy-loading issue)
  var throwAway = [ TARGET_PHASE_CLEAN, TARGET_PHASE_BUILD,
    TARGET_PHASE_ASSEMBLE, TARGET_PHASE_DEPLOY, TARGET_FULL ];

  return decl.getTargets(libraryName: libraryName);
}
