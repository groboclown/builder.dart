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

import '../resource.dart';
import 'target.dart';
import 'exceptions.dart';





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
   * Constructs a [target] from the standard ([String]) definitions, for use
   * in passing to the [BuildTool] constructor.  It does not wire anything up
   * to the [BuildTool] instance.
   */
  static target mkTargetDef(String name, String description,
      String phase, Pipe pipe, List<String> dependencies,
      List<String> weakDependencies) {
    if (! _PHASES.containsKey(phase)) {
      throw new NoSuchPhaseException(phase);
    }
    if (_OUTPUT_TARGETS.containsKey(name) || _PHASES.containsKey(name) ||
    _TOP_PHASE.containsKey(name)) {
      throw new MultipleTargetsWithSameNameException(name);
    }

    var targetDef = new target.internal(description, dependencies,
    weakDependencies, false);
    return targetDef;
  }
}



final Map<String, TargetMethod> _OUTPUT_TARGETS = <String, TargetMethod>{};
final Map<String, TargetMethod> _PHASES = <String, TargetMethod>{};
final Map<String, TargetMethod> _TOP_PHASE = <String, TargetMethod>{};
final Map<String, String> _PHASE_NAME_TO_TOP = <String, String>{};

List<TargetMethod> getTargets() {
  var ret = new List<TargetMethod>.from(_OUTPUT_TARGETS.values);
  ret.addAll(_PHASES.values);
  ret.addAll(_TOP_PHASE.values);
  return ret;
}


void _connectPipes(BuildTool tool) {
// FIXME connect this new tool to the list of existing output targets.
// Take special care with outputs that are shared by tools.
}


void _addToPhase(String phaseName, BuildTool tool) {
  var phaseGroup = _PHASES[phaseName];
  phaseGroup.targetDef.weakDepends.add(tool.name);
  var phaseTarget = _TOP_PHASE[_PHASE_NAME_TO_TOP[phaseName]];
  phaseTarget.targetDef.strongDepends.add(tool.name);
}



TargetMethod addPhase(String phaseName, String topTargetName,
    List<String> runsBefore, List<String> runsAfter) {
// FIXME insert the phase into the _PHASES list, and connect the runsBefore and runsAfter.
// The runsBefore and runsAfter are constructed as "weak" references.
// FIXME construct new phase targets that have a strong reference to the
// targets in that phase, so that a user can run the phase, rather than
// the individual targets.
// FIXME make sure to add the name mapping to _PHASE_NAME_TO_TOP.

}

