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


library builder.src.exceptions;

class BuildException extends Exception {
  final String message;

  BuildException(String message) :
    message = message,
    super(message);

  @override
  String toString() {
    return message;
  }
}


class BuildSetupException extends BuildException {
  BuildSetupException(String message) : super(message);
}


class NoDefaultTargetException extends BuildSetupException {
  NoDefaultTargetException() :
    super("no default target defined in build script");
}


class CyclicTargetDefinitionException extends BuildSetupException {
  final List<String> targetNames;

  CyclicTargetDefinitionException(this.targetNames) :
    super("found a cycle in the target dependencies for " + targetNames);
}


class MultipleTargetsWithSameNameException extends BuildSetupException {
  final String name;

  MultipleTargetsWithSameNameException(this.name) :
    super("multiple targets with name '" + name + " found");
}


class MissingTargetException extends BuildSetupException {
  final String definingTarget;
  final String dependentTarget;

  MissingTargetException(this.definingTarget, this.dependentTarget) :
    super("target '" + definingTarget + "' defines dependency on target '" +
      dependentTarget + "' which does not exist");
}
