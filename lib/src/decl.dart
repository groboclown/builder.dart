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
 * The declarative build tool internals.
 */

library builder.src.decl;

import 'dart:io';
import 'dart:mirrors';
import 'dart:async';

import 'resource.dart';
import 'target.dart';
import 'exceptions.dart';
import 'project.dart';
import 'pipe.dart';
export 'pipe.dart';



/// For internal use only (unit tests)
abstract class BuildTool_inner extends TargetMethod {
  final Pipe pipe;

  BuildTool_inner(String name, target targetDef, Pipe pipe) :
    this.pipe = pipe,
    super(name, targetDef);
}


/**
 * Top level build tool.  All declaration-based build tools extend this class.
 *
 * The usual pattern for a new [BuildTool] class has a factory constructor that
  * calls out to [BuildTool.mkTargetDef] to create the second argument of the
  * parent constructor.
 */
abstract class BuildTool extends BuildTool_inner {
  final TargetMethod phase;

  BuildTool(String name, target targetDef, String phase, Pipe pipe) :
      this.phase = _PHASES[phase],
      super(name, targetDef, pipe) {

    _addToPhase(phase, this);

    _connectPipes(this);

    _OUTPUT_TARGETS[name] = this;
  }



  /**
   * Fetch the list of files that have changed, which this tool uses as
   * inputs (either optional or required).  The setup method
   * ([computeChanges()]) must have been called first.
   *
   * Use this when the tool uses all the inputs together.  In the situations
   * where specific subsets of inputs are used for different purposes, use
   * [findChanged]
   */
  Iterable<Resource> getChangedInputs() {
    var ret = new Set<Resource>();
    ret.addAll(pipe.requiredInput.where((r) =>
      _CHANGED_RESOURCES.any((cr) => cr.matches(r))));
    ret.addAll(pipe.optionalInput.where((r) =>
      _CHANGED_RESOURCES.any((cr) => cr.matches(r))));
    return ret;
  }


  /**
   * Returns just the resources in the list which changed.  Use this method
   * rather than [getChangedInputs] when you need a specific sub-set of files,
   * instead of all the input files.
   */
  Iterable<Resource> findChanged(Iterable<Resource> rlist) {
    return rlist.where((r) => _CHANGED_RESOURCES.any((cr) => cr.matches(r)));
  }



  /**
   * Constructs a [target] from the standard ([String]) definitions, for use
   * in passing to the [BuildTool] constructor.  It does not wire anything up
   * to the [BuildTool] instance.
   */
  static target mkTargetDef(String name, String description,
      String phase, Pipe pipe, Iterable<String> dependencies,
      Iterable<String> weakDependencies) {
    if (! _PHASES.containsKey(phase)) {
      throw new NoSuchPhaseException(phase);
    }
    if (_OUTPUT_TARGETS.containsKey(name) || _PHASES.containsKey(name) ||
        _TOP_PHASES.containsKey(name)) {
      throw new MultipleTargetsWithSameNameException(name);
    }

    var targetDef = new target.internal(description, dependencies,
      weakDependencies, false);
    return targetDef;
  }
}


class PhaseTarget extends TargetMethod {
  final List<String> phaseRunsBefore;
  final List<String> phaseRunsAfter;
  
  factory PhaseTarget(String name, List<String> phaseRunsBefore,
      List<String> phaseRunsAfter) {
    var targetDef = new target.internal(name,
      <String>[], phaseRunsAfter, false);
    return new PhaseTarget._(name, targetDef, phaseRunsBefore, phaseRunsAfter);
  }
  
  PhaseTarget._(String name, target targetDef, List<String> phaseRunsBefore,
      List<String> phaseRunsAfter) :
    this.phaseRunsBefore = phaseRunsBefore,
    this.phaseRunsAfter = phaseRunsAfter,
    super(name, targetDef);
  
  
  void wire(Map<String, PhaseTarget> phaseMap) {
    // only need to wire up the before, because the after was done at
    // construction time.
    for (var before in phaseRunsBefore) {
      var phase = phaseMap[before];
      if (phase == null) {
        throw new MissingTargetException(name, before);
      }
      // note: duplicates are fine, they are ignored during the
      // ordering.
      //print("--Wiring " + name + " as dependency for " + phase.name);
      if (targetDef.weakDepends.contains(phase.name)) {
        throw new Exception("added ourself when it shouldn't have");
      }
      phase.targetDef.weakDepends.add(name);
    }
  }
  
  @override
  Future<Project> start(Project project) {
    // do nothing
    return new Future<Project>(() => project);
  }
}



class TopPhaseTarget extends TargetMethod {
  factory TopPhaseTarget(String name, PhaseTarget phase, bool isDefault) {
    var targetDef = new target.internal(name, <String>[],
      // we don't need a weak link to the phase, because the phase's targets
      // are added as strong dependencies to this top target.
      <String>[],
      isDefault);
    return new TopPhaseTarget._(name, targetDef);
  }

  TopPhaseTarget._(String name, target targetDef) :
    super(name, targetDef);

  @override
  Future<Project> start(Project project) {
    // do nothing
    return new Future<Project>(() => project);
  }
}




class VirtualTarget extends TargetMethod {
  factory VirtualTarget(String name, String description,
      Iterable<String> dependencies, Iterable<String> weakDependencies,
      [ bool isTop = false ]) {
    if (dependencies == null) {
      dependencies = <String>[];
    }
    if (weakDependencies == null) {
      weakDependencies = <String>[];
    }
    var targetDef = new target.internal(description,
      dependencies, weakDependencies, false);
    var ret = new VirtualTarget._(name, targetDef);
    if (isTop) {
      _TOP_PHASES[name] = ret;
    } else {
      _OUTPUT_TARGETS[name] = ret;
    }
    return ret;
  }

  VirtualTarget._(String name, target targetDef) :
    super(name, targetDef);

  @override
  Future<Project> start(Project project) {
    // do nothing
    return new Future<Project>(() => project);
  }
}



class NoOpTarget extends VirtualTarget {
  factory NoOpTarget(String name, String description) {
    var targetDef = new target.internal(description, <String>[], <String>[],
      false);
  }

  NoOpTarget._(String name, target targetDef) :
    super._(name, targetDef);

  @override
  Future<Project> start(Project project) {
    // do nothing
    return new Future<Project>(() {
      project.logger.info("nothing to do");
      return project;
    });
  }
}



final Map<String, TargetMethod> _OUTPUT_TARGETS = <String, TargetMethod>{};
final Map<String, PhaseTarget> _PHASES = <String, PhaseTarget>{};
final Map<String, TargetMethod> _TOP_PHASES = <String, TargetMethod>{};
final Map<String, String> _PHASE_NAME_TO_TOP = <String, String>{};


/**
 * NOTE: this function is heavily tied to the different data structures
 * in this file.  Updating the list of targets or phases will mean another
 * call into this function.
 */
List<TargetMethod> getTargets({ libraryName: "build" }) {
  if (_OUTPUT_TARGETS.isEmpty) {
    // Assume that all the targets are defined as top-level variables that
    // are lazy-loaded.
    for (LibraryMirror library in currentMirrorSystem().libraries.values) {
      if (MirrorSystem.getName(library.simpleName) == libraryName) {
        for (DeclarationMirror topLevel in library.declarations.values) {
          if (topLevel is VariableMirror) {
            library.getField(topLevel.simpleName);
          }
        }
      }
    }
  }
  
  if (_OUTPUT_TARGETS.isEmpty) {
    stderr.writeln("ERROR: no targets defined.  Did you remember to " +
      "put them inside the build.dart `void main(List<String> args)` " +
      "function?");
    exit(2);
  }
  
  // Wire up the phases
  for (var phase in _PHASES.values) {
    phase.wire(_PHASES);
  }
  
  var ret = new List<TargetMethod>.from(_OUTPUT_TARGETS.values);
  ret.addAll(_PHASES.values);
  ret.addAll(_TOP_PHASES.values);
  return ret;
}



void _addToPhase(String phaseName, BuildTool tool) {
  var phaseGroup = _PHASES[phaseName];
  phaseGroup.targetDef.weakDepends.add(tool.name);
  var phaseTarget = _TOP_PHASES[_PHASE_NAME_TO_TOP[phaseName]];
  phaseTarget.targetDef.strongDepends.add(tool.name);
  
  // DEBUG topo sort
  //print("topo-sort -- added " + tool.name + " as dependent to " + phaseTarget.name);
}


bool hasDefault = false;

/**
 * Creates the weak "phase" definition target and a top-level
 * Phase target.  The top-level target is returned.
 */
TargetMethod addPhase(String phaseName, String topTargetName,
    List<String> phaseRunsBefore, List<String> phaseRunsAfter,
    { isDefault: false }) {
  if (isDefault && hasDefault) {
    throw new MultipleDefaultTargetException();
  }
  hasDefault = hasDefault || isDefault;
  
  if (_PHASES.containsKey(phaseName)) {
    throw new MultipleTargetsWithSameNameException(phaseName);
  }
  if (_TOP_PHASES.containsKey(topTargetName)) {
    throw new MultipleTargetsWithSameNameException(topTargetName);
  }
  _PHASE_NAME_TO_TOP[phaseName] = topTargetName;
  
  // Create the weak targets
  var phaseTarget = new PhaseTarget(phaseName, phaseRunsBefore, phaseRunsAfter);
  _PHASES[phaseName] = phaseTarget;
  
  // Create the top-level targets
  // - It has a weak dependency on the phase, so it will be correctly sorted
  //   that way.
  _TOP_PHASES[topTargetName] = new TopPhaseTarget(topTargetName, phaseTarget,
      isDefault);
}


final Map<Resource, List<BuildTool_inner>> _PIPED_OUTPUT =
  <Resource, List<BuildTool_inner>>{};
final Map<Resource, List<BuildTool_inner>> _PIPED_INPUT =
  <Resource, List<BuildTool_inner>>{};



void _connectPipes(BuildTool tool) {
  connectPipe_internal(tool, _PIPED_INPUT, _PIPED_OUTPUT);
}


void connectPipe_internal(BuildTool_inner tm,
    Map<Resource, List<BuildTool_inner>> pipedInput,
    Map<Resource, List<BuildTool_inner>> pipedOutput) {
  // optionalInput is not connected int the piped input.

  // The "Reource" cannot use the "match" in the global piped* structures,
  // because they may not be correctly equal.

  for (var r in tm.pipe.requiredInput) {
    var links = pipedInput[r];
    if (links == null) {
      links = <BuildTool_inner>[];
      pipedInput[r] = links;
    }
    links.add(tm);

    // This is fairly inefficient.  A better data structure could tune down
    // the amount of loops in loops.

    pipedOutput.forEach((depr, deptools) => deptools.forEach((BuildTool_inner deptool) {
      // name check first, to omit the possibly long operation on
      // matches.
      if (! deptool.targetDef.strongDepends.contains(tm.name) &&
          depr.matches(r)) {
        tm.targetDef.strongDepends.add(deptool.name);
      }
    }));
  }

  //print("${tm} pipe output: ${tm.pipe.output}");
  for (var r in tm.pipe.output) {
    var links = pipedOutput[r];
    if (links == null) {
      links = <BuildTool_inner>[];
      pipedOutput[r] = links;
    }
    links.add(tm);

    pipedInput.forEach((depr, deptools) => deptools.forEach((BuildTool_inner deptool) {
      // name check first, to omit the possibly long operation on matches.
      if (! tm.targetDef.strongDepends.contains(deptool.name) &&
          r.matches(depr)) {
        deptool.targetDef.strongDepends.add(tm.name);
      }
    }));
  }
}


final _CHANGED_RESOURCES = new Set<Resource>();



/**
 * Computes the [Resource] changes based on the [Project] listed changed
 * files, chained up through the targets.  Returns a [List] of [TargetMethod]
 * instances that are affected by those changes.
 */
List<TargetMethod> computeChanges(Project project) {
  _CHANGED_RESOURCES.clear();
  _CHANGED_RESOURCES.addAll(project.changed.entries());
  _CHANGED_RESOURCES.addAll(project.removed.entries());
  return computeChanges_inner(_CHANGED_RESOURCES, _PIPED_INPUT);
}



// computeChanges that's designed for testing.
List<BuildTool_inner> computeChanges_inner(Set<Resource> changedFiles,
    Map<Resource, List<BuildTool_inner>> pipedInput) {
  var validateStack = new List<Resource>.from(changedFiles);
  var ret = new Set<BuildTool_inner>();
  var seenFiles = new Set<Resource>();

  while (! validateStack.isEmpty) {
    var next = validateStack.removeLast();
    if (! seenFiles.contains(next)) {
      seenFiles.add(next);
      changedFiles.add(next);
      //print("X- ${next}...");
      pipedInput.forEach((Resource depres, List<BuildTool_inner> deptools) {
        //print("X-- checking ${depres}");
        if (next.matches(depres)) {
          validateStack.add(depres);
          deptools.forEach((BuildTool_inner deptool) {
            ret.add(deptool);
            var matched = deptool.pipe.matchOutput(next);
            //print("X--- match on " + deptool.name);
            validateStack.addAll(matched);
          });
        }
      });
    }
  }

  return new List<BuildTool_inner>.from(ret);
}

