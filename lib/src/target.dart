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
 * Definitions on a "target" - a callable that has:
 *
 * 1. A name and description.
 * 2. Dependent targets.
 * 3. An invocable callback.
 *
 * Additionally, each build must define exactly one target as the default.
 */


library builder.src.target;

import 'dart:mirrors';
import 'dart:collection';
import 'dart:async';

import 'project.dart';

/**
 * A target description.  Can be used as an annotation in the procedural
 * build approach.
 */
class target {
  final bool isDefault;
  final String description;

  /**
   * Defines the ordering relationship.  Implicitly includes all the strong
   * dependencies.
   */
  final Set<String> weakDepends;

  /**
   * Defines which targets will be built if this one is built.
   */
  final Set<String> strongDepends;

  factory target(String description,
      { Iterable<String> depends: null, Iterable<String> weak: null }) {
    return new target._(description,
      _asStringSet(depends), _asStringSet(weak), false);
  }

  factory target.main(String description,
      { Iterable<String> depends: null, Iterable<String> weak: null }) {
    return new target._(description,
      _asStringSet(depends), _asStringSet(weak), true);
  }


  /**
   * A "friend" constructor, used by tool.dart.
   */
  factory target.internal(String description,
      Iterable<String> depends, Iterable<String> weak, bool isDefault) {
    return new target._(description,
    _asStringSet(depends), _asStringSet(weak), isDefault);
  }


  const target._(this.description, this.strongDepends, this.weakDepends,
      this.isDefault);
}



/**
 * The abstract class that defines the actual invocable target.
 */
abstract class TargetMethod {
  final String name;
  final target targetDef;

  TargetMethod(this.name, this.targetDef);

  List<String> get runsAfter {
    var ret = new Set<String>.from(targetDef.weakDepends);
    ret.addAll(targetDef.strongDepends);
    return new UnmodifiableListView<String>(ret);
  }

  List<String> get requires =>
      new UnmodifiableListView<String>(targetDef.strongDepends);



  /**
   * Performs the operation of the target.  It throws a [BuildException]
   * on an error (see [exceptions.dart]).
   */
  Future<Project> start(Project project);
}


class AnnotatedTarget extends TargetMethod {
  final InstanceMirror owner;
  final MethodMirror method;

  AnnotatedTarget(target targetDef, InstanceMirror owner, MethodMirror method) :
    owner = owner,
    method = method,
    super(MirrorSystem.getName(method.simpleName), targetDef);

  @override
  Future<Project> start(Project project) {
    return new Future<Project>(() {
      InstanceMirror im = owner.invoke(method.simpleName, [ project ]);
      // Does this need explicit error checking?

      return project;
    });
  }

}



/**
 * Creates the build targets that are defined in a builder Class.
 */
List<TargetMethod> parseTargets(Type builder) {
  ClassMirror cm = reflectClass(builder);

  // Find the constructor & targets

  var constructor;
  var targets = <MethodMirror, target>{};

  cm.declarations.values.where((m) => m is MethodMirror)
    .forEach((m) {
      if (m.isConstructor && m.parameters.length == 0) {
        // TODO Could check here for multiple no-arg constructors...
        constructor = m;
      } else if (! m.isStatic && m.isRegularMethod && ! m.isOperator &&
          m.parameters.length == 1
          // TODO may need to fix this to be correect
          && MirrorSystem.getName(m.parameters[0].type.simpleName) == 'Project'
          ) {
        // Add all methods that have a 'target' annotation
        m.metadata.where((t) => MirrorSystem.getName(t.type.simpleName) == 'target')
          .forEach((t) => targets[m] = t);
      }
    });
  if (constructor == null) {
    throw new Exception("invalid builder ${builder}: no no-arg constructor");
  }

  // Create our builder
  var buildInstance = cm.invoke(constructor, []).reflectee;

  // Create our returns
  var ret = <TargetMethod>[];
  targets.forEach((mm, t) => ret.add(new AnnotatedTarget(t, buildInstance, mm)));

  // This should be done in the caller
  //var defaults = ret.where((t) => t.targetDef.isDefault);
  //if (defaults.length != 1) {
  //  throw new Exception("invalid builder ${builder}: there must be exactly 1 default target");
  //}

  return ret;
}


Set<String> _asStringSet(Iterable<String> x) {
  Set<String> s;
  if (x == null) {
    s = new Set<String>();
  } else if (x is Set<String>) {
    s = x;
  } else {
    s = new Set<String>.from(x);
  }
  return s;
}
