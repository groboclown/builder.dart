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
 */


library builder.src.targetmethod;

import 'dart:mirrors';
import 'dart:collection';
import 'dart:async';

import 'project.dart';


class TargetDef {
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

  TargetDef(String description, Iterable<String> strongDepends,
      Iterable<String> weakDepends, bool isDefault) :
    this.description = description,
    this.strongDepends = _asStringSet(strongDepends),
    this.weakDepends = _asStringSet(weakDepends),
    this.isDefault = isDefault;
}



/**
 * The abstract class that defines the actual invocable target.
 */
abstract class TargetMethod {
  final String name;
  final TargetDef targetDef;

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
   * on an error (see [exceptions.dart]).  A return value of `null` indicates
   * that all processing occurred within the call, otherwise it returns a
   * [Future] object that completes when the target completes.
   */
  Future start(Project project);
}


class AnnotatedTarget extends TargetMethod {
  final InstanceMirror owner;
  final MethodMirror method;

  AnnotatedTarget(TargetDef targetDef, InstanceMirror owner, MethodMirror method) :
    owner = owner,
    method = method,
    super(MirrorSystem.getName(method.simpleName), targetDef);

  @override
  Future start(Project project) {
    return new Future(() {
      InstanceMirror im = owner.invoke(method.simpleName, [ project ]);
      // Does this need explicit error checking?
    });
  }

}


Set<String> _asStringSet(Iterable<String> x) {
  Set<String> s;
  if (x == null) {
    s = new Set<String>();
  }
  else if (x is Set<String>) {
    s = x;
  }
  else {
    s = new Set<String>.from(x);
  }
  return s;
}
