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



library builder.src.target;

import 'dart:mirrors';

import 'project.dart';

/**
 * Annotation class to define a target.
 */
class target {
  final bool isDefault;
  final String description;
  final List<String> depends;

  factory target(String description,
      { List<String> depends: null }) {
    return new target._(description, depends, false);
  }

  factory target.main(String description,
      { List<String> depends: null }) {
    return new target._(description, depends, true);
  }

  const target._(this.description, this.depends, this.isDefault);
}


class TargetMethod {
  final target targetDef;
  final InstanceMirror owner;
  final MethodMirror method;

  const TargetMethod(this.targetDef, this.owner, this.method);

  String get name => MirrorSystem.getName(method.simpleName);

  String get description => targetDef.description;


  void call(Project project) {
    InvocationMirror im = owner.invoke(method.simpleName, [project]);
  }
}



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
        m.metadata.where((t) => MirrorSystem.getName(t.simpleName) == 'target')
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
  targets.forEach((mm, t) => ret.add(new TargetMethod(t, buildInstance, mm)));

  var defaults = ret.where((t) => t.targetDef.isDefault);
  if (defaults.length != 1) {
    throw new Exception("invalid builder ${builder}: there must be exactly 1 default target");
  }

  return ret;
}
