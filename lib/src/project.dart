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
import '../resource.dart';

class Project {
  final AbstractLogger _baseLogger;
  final List<TargetMethod> _targets;
  final List<TargetMethod> _invokedTargets = [];
  final Map<String, String> _properties = {};
  final ResourceCollection changed;
  final ResourceCollection removed;

  Project.parse(BuildArgs args) :
      _baseLogger = args.logger,
      _targets = args.allTargets,
      changed = filenamesAsCollection(args.changed),
      removed = filenamesAsCollection(args.removed);

  Project._fromChild(Project parent) :
      _baseLogger = parent._baseLogger,
      _targets = null,
      changed = null,
      removed = null;

  TargetMethod get activeTarget {
    throw new NoRunningTargetException();
  }

  Logger get logger {
    throw new NoRunningTargetException();
  }


  List<TargetMethod> get targets => new List<TargetMethod>.from(_targets);

  List<String> get targetNames => new List<String>.from(_targets.map((t) => t.name));

  String getProperty(String key) {
    return _properties[key];
  }

  bool hasProperty(String key) {
    return _properties.containsKey(key);
  }

  void setProperty(String key, String value) {
    if (hasProperty(key)) {
      throw new PropertyRedefinitionException(activeTarget, key,
        getProperty(key), value);
    }
  }

  TargetMethod findTarget(String name) {
    for (TargetMethod tm in _targets) {
      if (tm.name == name) {
        return tm;
      }
    }
    return null;
  }


  void build(String target) {
    buildTargets([ findTarget(target) ]);
  }


  /**
   * Run the full build for this specific [TargetMethod].  It will not repeat
   * any target that has already been run in this project.
   */
  void buildTargets(List<TargetMethod> targets) {
    if (targets == null) {
      throw new Exception("null target");
    }

    // run the dependencies and the target.  Only check the whole dependency
    // tree if this is the first target run.
    for (TargetMethod tm in _dependencyList(targets, _invokedTargets.isEmpty)) {
      if (! _invokedTargets.contains(tm)) {
        _invokedTargets.add(tm);

        // This could be a future, as long as the dependency list is honored
        // and checked for completion before running.  It would mean changing
        // the _invokedTargets to instead be a Map of futures.

        Project child = new _ChildProject(this, tm);
        tm.call(child);

      }
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
    var state = <TargetMethod, _TOPO_STATE>{};
    var visiting = <String>[];

    // Run a depth-first-search using each root as a starting node.
    // This creates the minimum target list to run.
    for (TargetMethod tm in roots) {
      if (! state.containsKey(tm)) {
        _tsort(tm, state, visiting, ret);
      } else if (state[tm] == _TOPO_STATE.VISITING) {
        throw new CyclicTargetDefinitionException(visiting);
      }
    }


    // Optionally, run the sort on all unvisited targets to detect
    // cycles or missing target dependencies.
    if (complete) {
      for (TargetMethod currentTarget in _targets) {
        if (! state.containsKey(currentTarget)) {
          _tsort(currentTarget, state, visiting, ret);
        } else if (state[currentTarget] == _TOPO_STATE.VISITING) {
          throw new CyclicTargetDefinitionException(visiting);
        }
      }
    }
    return ret;
  }


  /**
   * One step in the recursive depth-first-search traversal.
   */
  void _tsort(TargetMethod root, Map<TargetMethod, _TOPO_STATE> state,
      List<String> visiting, List<TargetMethod> ret) {
    state[root] = _TOPO_STATE.VISITING;
    visiting.add(root.name);

    for (String dependentName in root.targetDef.depends) {
      TargetMethod dependent = _findTarget(dependentName);
      if (dependent == null) {
        throw new MissingTargetException(root.name, dependentName);
      }
      if (! state.containsKey(dependent)) {
        // needs to be visited
        _tsort(dependent, state, visiting, ret);
      } else if (state[dependent] == _TOPO_STATE.VISITING) {
        throw new CyclicTargetDefinitionException(visiting);
      }
    }
    var visitor = visiting.removeLast();
    if (visitor != root.name) {
      throw new BuildSetupException("internal error: expected '" + root.name +
      "' but found '" + visitor + "'");
    }
    state[root] = _TOPO_STATE.VISITED;
    ret.add(root);
  }

}

// FIXME figure out the right way to use @proxy
class _ChildProject extends Project {
  final Project _parent;
  final TargetMethod _activeTarget;
  final Logger _logger;

  _ChildProject(Project parent, TargetMethod activeTarget) :
      _parent = parent,
      _activeTarget = activeTarget,
      _logger = new Logger(activeTarget, parent._baseLogger),
      super._fromChild(parent);


  @override
  TargetMethod get activeTarget => _activeTarget;

  @override
  Logger get logger => _logger;

  @override
  List<TargetMethod> get targets => _parent.targets;

  @override
  List<String> get targetNames => _parent.targetNames;

  @override
  String getProperty(String key) => _parent.getProperty(key);

  @override
  bool hasProperty(String key) => _parent.hasProperty(key);

  @override
  void setProperty(String key, String value) => _parent.setProperty(key, value);

  @override
  TargetMethod findTarget(String name) => _parent.findTarget(name);

  @override
  void build(String target) => _parent.build(target);

  @override
  void buildTargets(List<TargetMethod> targets) => _parent.buildTargets(targets);

}



class _TOPO_STATE {
  static final VISITING = new _TOPO_STATE._();
  static final VISITED = new _TOPO_STATE._();

  static get values => [ VISITED, VISITING ];

  _TOPO_STATE._();
}
