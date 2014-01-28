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



library builder.src.project;

import 'logger.dart';
import 'argparser.dart';
import 'target.dart';
import 'exceptions.dart';

class Project {
  final Logger logger;
  final List<TargetMethod> _targets;
  final List<TargetMethod> _invokedTargets = [];
  final Map<String, String> properties = {};

  Project.parse(BuildArgs args) :
      logger = args.logger,
      _targets = args.allTargets;


  List<TargetMethod> get targets => new List<TargetMethod>.from(_targets);

  List<String> get targetNames => new List<String>.from(_targets.map((t) => t.name));

  TargetMethod findTarget(String name) {
    for (TargetMethod tm in _targets) {
      if (tm.name == name) {
        return tm;
      }
    }
    return null;
  }


  void build(String target) {
    buildTarget(findTarget(target));
  }


  /**
   * Run the full build for this specific [TargetMethod].  It will not repeat
   * any target that has already been run in this project.
   */
  void buildTarget(TargetMethod m) {
    if (m == null) {
      throw new Exception("null target");
    }
    if (_invokedTargets.contains(m)) {
      // do nothing
      return;
    }

    // run the dependencies and the target
    for (TargetMethod tm in _dependencyList(m)) {
      tm.call(this);
    }
  }


  TargetMethod _findTarget(String name) {
    var matches = _targets.where((t) => t.name == name);
    if (matches.isEmpty) {
      return null;
    }
    if (matches.length > 1) {
      throw new MultipleTargetsWithSameNameException(name);
    }
    return matches[0];
  }


  /**
   * Return the list of targets to execute for this target, which means
   * constructing an ordered dependency chain (including `m` at the very
   * end), excluding all the already-executed dependencies.
   *
   * This is a simple topological sort.  It returns only the targets that
   * are dependents of the roots.
   *
   * If `complete` is `true`, then the complete dependency graph is generated
   * in order to check for cycles or missing dependencies.
   */
  List<TargetMethod> _dependencyList(List<TargetMethod> roots, bool complete) {
    var ret = <TargetMethod>[];
    var state = <TargetMethod, TOPO_STATE>{};
    var visiting = <String>[];

    // Run a depth-first-search using each root as a starting node.
    // This creates the minimum target list to run.
    for (TargetMethod tm in roots) {
      if (! state.containsKey(tm)) {
        _tsort(tm, state, visiting, ret);
      } else if (state[tm] == TOPO_STATE.VISITING) {
        throw new CyclicTargetDefinitionException(visiting);
      }
    }


    // Optionally, run the sort on all unvisited targets to detect
    // cycles or missing target dependencies.
    if (complete) {
      for (TargetMethod currentTarget in _targets) {
        if (! state.containsKey(currentTarget)) {
          _tsort(tm, state, visiting, ret);
        } else if (state[currentTarget] == TOPO_STATE.VISITING) {
          throw new CyclicTargetDefinitionException(visiting);
        }
      }
    }
    return ret;
  }


  /**
   * One step in the recursive depth-first-search traversal.
   */
  void _tsort(TargetMethod root, Map<TargetMethod, TOPO_STATE> state,
      List<String> visiting, List<TargetMethod> ret) {
    state[root] = TOPO_STATE.VISITING;
    visiting.add(root.name);

    for (String dependentName in root.targetDef.depends) {
      TargetMethod dependent = _findTarget(dependentName);
      if (dependent == null) {
        throw new MissingTargetException(root.name, dependentName);
      }
      if (! state.containsKey(dependent)) {
        // needs to be visited
        _tsort(dependent, state, visiting, ret);
      } else if (state[dependent] == TOPO_STATE.VISITING) {
        throw new CyclicTargetDefinitionException(visiting);
      }
    }
    var visitor = visiting.removeLast();
    if (visitor != root.name) {
      throw new BuildSetupException("internal error: expected '" + root.name +
      "' but found '" + visitor + "'");
    }
    state[root] = TOPO_STATE.VISITED;
    ret.add(root);
  }

}



class TOPO_STATE {
  static final VISITING = new TOPO_STATE._();
  static final VISITED = new TOPO_STATE._();

  static get values => [ VISITED, VISITING ];

  TOPO_STATE._();
}
