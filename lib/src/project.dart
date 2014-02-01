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

import 'dart:async';

import 'logger.dart';
import 'argparser.dart';
import 'target.dart';
import 'exceptions.dart';
import '../os.dart';
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
      _targets = new List<TargetMethod>.from(args.allTargets, growable: false),
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


  Iterable<TargetMethod> get targets => _targets;

  Iterable<String> get targetNames => _targets.map((t) => t.name);

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

    Project parent = this;

    // run the dependencies and the target.  Only check the whole dependency
    // tree if this is the first target run.

    List<FutureFactory<Project>> futures = <FutureFactory<Project>>[];

    for (TargetMethod tm in _dependencyList(targets, _invokedTargets.isEmpty)) {
      if (! _invokedTargets.contains(tm)) {
        futures.add(new FutureFactory<Project>(() {
          var p = new _ChildProject(parent, tm);
          p.logger.info("=>");
          return tm.start(p).then((p) { p.logger.info("<="); return p;});
        }));
        _invokedTargets.add(tm);
      }
    }

    new Sequential<Project>(futures).call().drain();
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
   *
   * This is specially structured to allow a double sorting.  Each
   * [TargetMethod] has a list of required dependencies - if the target
   * itself must build, then all the required dependencies must also build,
   * and it also has a weak sorting - it must run after all the weakly
   * dependent targets, but they are not required to run.
   */
  Iterable<TargetMethod> _dependencyList(Iterable<TargetMethod> roots,
      bool complete) {
    Map<String, _TargetOrder> orders = <String, _TargetOrder>{};
    List<_TargetOrder> orderedRoots = <_TargetOrder>[];
    for (TargetMethod tm in _targets) {
      var order = new _TargetOrder(tm);
      orders[tm.name] = order;
      if (roots.contains(tm)) {
        order.required = true;
        orderedRoots.add(order);
      }
    }


    var ret = <_TargetOrder>[];
    var state = <_TargetOrder, _TOPO_STATE>{};
    var visiting = <String>[];

    // Run a depth-first-search using each root as a starting node.
    // This creates the minimum target list to run.
    for (_TargetOrder tm in orderedRoots) {
      if (! state.containsKey(tm)) {
        _tsort(tm, state, orders, visiting, ret);
      } else if (state[tm] == _TOPO_STATE.VISITING) {
        throw new CyclicTargetDefinitionException(visiting);
      }
    }

    // Collect all the TargetMethod instances that are required to run.
    var tmRet = ret.map((tm) => tm.required ? tm.tm : null).where((tm) => tm != null);

    // Optionally, run the sort on all unvisited targets to detect
    // cycles or missing target dependencies.  These are not added to the
    // returned values.
    if (complete) {
      for (_TargetOrder currentTarget in orders.values) {
        if (! state.containsKey(currentTarget)) {
          _tsort(currentTarget, state, orders, visiting, ret);
        } else if (state[currentTarget] == _TOPO_STATE.VISITING) {
          throw new CyclicTargetDefinitionException(visiting);
        }
      }
    }
    return tmRet;
  }


  /**
   * One step in the recursive depth-first-search traversal.
   */
  void _tsort(_TargetOrder root, Map<_TargetOrder, _TOPO_STATE> state,
      Map<String, _TargetOrder> orders, List<String> visiting,
      List<_TargetOrder> ret) {
    // DEBUG topo sort
    //print("topo-sort->" + root.tm.name);
    
    state[root] = _TOPO_STATE.VISITING;
    visiting.add(root.tm.name);

    for (var dependentName in root.tm.runsAfter) {
      // DEBUG topo sort
      //print("   " + root.tm.name + " -> " + dependentName +
      //  (root.tm.targetDef.weakDepends.contains(dependentName) ? " (weak)" : ""));
      
      if (! orders.containsKey(dependentName)) {
        throw new MissingTargetException(root.tm.name, dependentName);
      }
      var dependent = orders[dependentName];

      if (root.required && root.tm.requires.contains(dependentName)) {
        dependent.required = true;
      }

      if (! state.containsKey(dependent)) {
        // needs to be visited
        _tsort(dependent, state, orders, visiting, ret);
      } else if (state[dependent] == _TOPO_STATE.VISITING) {
        throw new CyclicTargetDefinitionException(visiting);
      }
    }
    var visitor = visiting.removeLast();
    if (visitor != root.tm.name) {
      throw new BuildSetupException("internal error: expected '" +
          root.tm.name + "' but found '" + visitor + "'");
    }
    state[root] = _TOPO_STATE.VISITED;
    ret.add(root);
    
    // DEBUG topo sort
    //print("topo-sort<- "+root.tm.name);
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


class _TargetOrder {
  final TargetMethod tm;
  bool required;

  _TargetOrder(this.tm) : required = false;
}



class _TOPO_STATE {
  static final VISITING = new _TOPO_STATE._();
  static final VISITED = new _TOPO_STATE._();

  static get values => [ VISITED, VISITING ];

  _TOPO_STATE._();
}
