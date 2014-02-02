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

import 'target.dart';

class BuildException implements Exception {
  final String message;

  BuildException(String message) :
    message = message;

  @override
  String toString() {
    return message;
  }
}


/**
 * There was something wrong with the initial setup of the build script.
 */
class BuildSetupException extends BuildException {
  BuildSetupException(String message) : super(message);
}


/**
 * The execution of the build caused a problem.
 */
class BuildExecutionException extends BuildException {
  final TargetMethod target;

  BuildExecutionException(this.target, String message) : super(message);
}


class NoDefaultTargetException extends BuildSetupException {
  NoDefaultTargetException() :
    super("no default target defined in build script");
}


class MultipleDefaultTargetException extends BuildSetupException {
  MultipleDefaultTargetException() :
    super("multiple targets defined as `default` in build script");
}


class CyclicTargetDefinitionException extends BuildSetupException {
  final List<String> targetNames;

  CyclicTargetDefinitionException(List<String> targetNames) :
    this.targetNames = targetNames,
    super("found a cycle in the target dependencies for " + targetNames.toString());
}


class MultipleTargetsWithSameNameException extends BuildSetupException {
  final String name;

  MultipleTargetsWithSameNameException(String name) :
    this.name = name,
    super("multiple targets with name '" + name + " found");
}


class MissingTargetException extends BuildSetupException {
  final String definingTarget;
  final String dependentTarget;

  MissingTargetException(String definingTarget, String dependentTarget) :
    this.definingTarget = definingTarget,
    this.dependentTarget = dependentTarget,
    super("target '" + definingTarget + "' defines dependency on target '" +
      dependentTarget + "' which does not exist");
}


class PropertyRedefinitionException extends BuildExecutionException {
  final String propertyName;
  final String originalPropertyValue;
  final String replacedPropertyValue;

  PropertyRedefinitionException(TargetMethod target, String propertyName,
      String originalPropertyValue, String replacedPropertyValue) :
      this.propertyName = propertyName,
      this.originalPropertyValue = originalPropertyValue,
      this.replacedPropertyValue = replacedPropertyValue,
      super(target, "target '" + target.name +
        "' attempted to redefine property '" + propertyName + "' from '" +
        originalPropertyValue + "' to '" + replacedPropertyValue + "'");
}


class ToolException extends BuildExecutionException {
  final String file;
  final int line;
  final int charStart;
  final int charEnd;
  final String failureMessage;

  ToolException(TargetMethod target, String file,
                int line, int charStart, int charEnd, String failureMessage) :
    this.file = file,
    this.line = line,
    this.charStart = charStart,
    this.charEnd = charEnd,
    this.failureMessage = failureMessage,
    super(target, ToolException._toString(
        target, file, line, charStart, charEnd, failureMessage));


  static String _toString(TargetMethod target, String file,
      int line, int charStart, int charEnd, String failureMessage) {
    var msg = new StringBuffer("target '");
    msg
      ..write(target == null ? "(unknown)" : target.name)
      ..write("' failed with '")
      ..write(failureMessage)
      ..write("'");
    if (file != null) {
      msg
        ..write(" on '")
        ..write(file)
        ..write("'");
      if (line != null) {
        msg
          ..write(" line ")
          ..write(line);
      }
      if (charStart != null) {
        if (line != null) {
          msg.write(", ");
        }
        msg
          ..write(" column ")
          ..write(charStart);
        if (charEnd != null) {
          msg
            ..write("-")
            ..write(charEnd);
        }
      }
    }
    return msg.toString();
  }
}



class NoRunningTargetException extends BuildSetupException {
  NoRunningTargetException() : super("no running target");
}


class NoSuchPhaseException extends BuildSetupException {
  NoSuchPhaseException(String phase) :
    super("no such phase defined: '" + phase +
      "'; it must be created before being referenced");
}
