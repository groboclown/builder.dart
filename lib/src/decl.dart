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



/**
 * Describes how a [BuildTool] connects with the resources.
 */
abstract class Pipe {
  /**
   * All inputs that are required to exist before the [BuildTool] can run.
   * These must be defined before the build runs.
   */
  List<Resource> get requiredInput;

  /**
   * All the input [Resource] that, if they are generated by another build
   * tool, will be run before the [BuildTool].
   */
  List<Resource> get optionalInput;

  /**
   * As many [Resource] that can be anticipated to be generated by the
   * tool.  Where possible, this should be all the precise resources,
   * or, if the tool generates a bunch of files whose name can't be
   * accurately predicted, then at least the directory into which they
   * will be placed.
   *
   * Multiple build tools can output into the same directory.
   */
  List<Resource> get output;

  /**
   * Any input that can be mapped directly to one or more [Resource]
   * should include a direct pipe reference to allow for more efficient
   * building.
   */
  Map<Resource, List<Resource>> get directPipe;


  /**
   * Match the given input to the corresponding output [Resource]s.  It first
   * uses the [#directPipe] before defaulting to the [#output].  If there
   * were no matches, it returns an empty list.
   */
  List<Resource> matchOutput(Resource input) {
    for (var r in directPipe) {
      if (input.matches(r)) {
        return directPipe[r];
      }
    }

    for (var r in requiredInput) {
      if (input.matches(r)) {
        return output;
      }
    }
    for (var r in optionalInput) {
      if (input.matches(r)) {
        return output;
      }
    }

    return <Resource>[];
  }




  factory Pipe.direct(Map<Resource, List<Resource>> direct) {
    return new SimplePipe.direct(direct);
  }


  factory Pipe.single(Resource input, Resource output) {
    return new SimplePipe.single(input, output);
  }


  factory Pipe.list(List<Resource> inputs, List<Resource> outputs) {
    return new SimplePipe.list(inputs, outputs);
  }


  factory Pipe.all({ Iterable<Resource> requiredInput: null,
      Iterable<Resource> optionalInput: null,
      Iterable<Resource> output: null,
      Map<Resource, Iterable<Resource>> directPipe: null }) {
    if (requiredInput == null) {
      requiredInput = <Resource>[];
    }
    if (optionalInput == null) {
      optionalInput = <Resource>[];
    }
    if (directPipe == null) {
      directPipe = <Resource, List<Resource>>{};
    }
    return new SimplePipe.all(requiredInput: requiredInput,
      optionalInput: optionalInput, output: output, directPipe: directPipe);
  }


  Pipe() {}
}


class SimplePipe extends Pipe {
  final Set<Resource> _requiredInput = new Set<Resource>();
  final Set<Resource> _optionalInput = new Set<Resource>();
  final Set<Resource> _output = new Set<Resource>();
  final Map<Resource, Iterable<Resource>> _directPipe =
    <Resource, Iterable<Resource>>{};

  SimplePipe.direct(Map<Resource, Iterable<Resource>> direct) {
    // Ensure we don't have duplicates in the wrong places
    for (var r in direct.keys) {
      _requiredInput.add(r);
      Set<Resource> out = new Set<Resource>.from(direct[r]);
      _directPipe[r] = out;
      _output.addAll(out);
    }
  }


  SimplePipe.single(Resource input, Resource output) {
    if (input != null) {
      _requiredInput.add(input);
    }
    if (output != null) {
      _output.add(output);
    }
    if (input != null && output != null) {
      _directPipe[input] = [ output ];
    }
  }


  SimplePipe.list(Iterable<Resource> inputs, Iterable<Resource> outputs) {
    if (inputs != null) {
      _requiredInput.addAll(inputs);
    }
    if (outputs != null) {
      _output.addAll(outputs);
    }
  }


  SimplePipe.all({ Iterable<Resource> requiredInput: null,
      Iterable<Resource> optionalInput: null,
      Iterable<Resource> output: null,
      Map<Resource, Iterable<Resource>> directPipe: null }) {
    if (requiredInput != null) {
      _requiredInput.addAll(new Set<Resource>.from(requiredInput));
    }
    if (optionalInput != null) {
      _optionalInput.addAll(new Set<Resource>.from(optionalInput));
    }

    var out = new Set<Resource>();
    if (output != null) {
      out.addAll(output);
    }

    if (directPipe != null) {
      for (Resource r in directPipe.keys) {
        if (! _requiredInput.contains(r) && ! _optionalInput.contains(r)) {
          _optionalInput.add(r);
        }
        _directPipe[r] = new Set<Resource>.from(directPipe[r]);
        out.addAll(_directPipe[r]);
      }
    }
    _output.addAll(out);
  }


  @override
  Iterable<Resource> get requiredInput => _requiredInput;

  @override
  Iterable<Resource> get optionalInput => _optionalInput;

  @override
  Iterable<Resource> get output => _output;

  @override
  Map<Resource, Iterable<Resource>> get directPipe => _directPipe;
}






/**
 * Top level build tool.
 */
abstract class BuildTool extends TargetMethod {
  final TargetMethod phase;
  final Pipe pipe;

  BuildTool(String name, target targetDef, String phase, Pipe pipe) :
      this.phase = _PHASES[phase],
      this.pipe = pipe,
      super(name, targetDef) {

    _addToPhase(phase, this);

    _connectPipes(this);

    _OUTPUT_TARGETS[name] = this;
  }



  /**
   * Fetch the list of files that have changed, which this tool uses as
   * inputs (either optional or required).  The setup method
   * ([computeChanges()]) must have been called first.
   */
  Iterable<Resource> getChangedInputs() {
    var ret = new Set<Resource>();
    for (var r in pipe.requiredInput) {
      ret.addAll(_CHANGED_RESOURCES.where((cr) => r.matches(cr)));
    }
    for (var r in pipe.optionalInput) {
      ret.addAll(_CHANGED_RESOURCES.where((cr) => r.matches(cr)));
    }
    return ret;
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


final Map<Resource, List<BuildTool>> _PIPED_OUTPUT =
  <Resource, List<BuildTool>>{};
final Map<Resource, List<BuildTool>> _PIPED_INPUT =
  <Resource, List<BuildTool>>{};



void _connectPipes(BuildTool tool) {
  // optionalInput is not connected int the piped input.

  // The "Reource" cannot use the "match" in the global piped* structures,
  // because they may not be correctly equal.

  for (var r in tool.pipe.requiredInput) {
    var links = _PIPED_INPUT[r];
    if (links == null) {
      links = <BuildTool>[];
      _PIPED_INPUT[r] = links;
    }
    links.add(tool);

    // This is fairly ineficcient.  A better data structure could tune down
    // the amount of loops in loops.

    _PIPED_OUTPUT.forEach((depr, deptools) => deptools.forEach((deptool) {
      // name check first, to omit the possibly long operation on
      // matches.
      if (! deptool.targetDef.strongDepends.contains(tool.name) &&
          depr.matches(r)) {
        deptool.targetDef.strongDepends.add(tool.name);
      }
    }));
  }

  for (var r in tool.pipe.output) {
    var links = _PIPED_OUTPUT[r];
    if (links == null) {
      links = <BuildTool>[];
      _PIPED_OUTPUT[r] = links;
    }
    links.add(tool);

    _PIPED_INPUT.forEach((depr, deptools) => deptools.forEach((deptool) {
      // name check first, to omit the possibly long operation on
      // matches.
      if (! tool.targetDef.strongDepends.contains(deptool.name) &&
          r.matches(depr)) {
        tool.targetDef.strongDepends.add(deptool.name);
      }
    }));
  }
}


final Set<Resource> _CHANGED_RESOURCES = new Set<Resource>();


/**
 * Computes the [Resource] changes based on the [Project] listed changed
 * files, chained up through the targets.  Returns a [List] of [TargetMethod]
 * instances that are affected by those changes.
 */
List<TargetMethod> computeChanges(Project project) {
  var ret = new Set<TargetMethod>();
  _CHANGED_RESOURCES.clear();
  var validateStack = <Resource>[];
  _CHANGED_RESOURCES.addAll(project.changed.entries());
  _CHANGED_RESOURCES.addAll(project.removed.entries());
  validateStack.addAll(_CHANGED_RESOURCES);

  while (! validateStack.isEmpty) {
    var next = validateStack.removeLast();
    if (! _CHANGED_RESOURCES.contains(next)) {
      _CHANGED_RESOURCES.add(next);
      _PIPED_INPUT.forEach((depres, deptools) {
        if (next.matches(depres)) {
          validateStack.add(depres);
          deptools.forEach((deptool) {
            ret.add(deptool);
            validateStack.addAll(deptool.pipe.matchOutput(next));
          });
        }
      });
    }
  }

  return new List<TargetMethod>.from(ret);
}
