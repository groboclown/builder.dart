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


library builder.src.failure;


import '../resource.dart';
import 'project.dart';
import 'exceptions.dart';

class Failure {
  final Project project;
  final String failureMessage;
  final Resource resource;
  final int line;
  final int charStart;
  final int charEnd;

  const Failure(Project project, String failureMessage, {
    Resource resource: null,
    int line: null,
    int charStart: null,
    int charEnd: null
  }) :
    this.project = project,
    this.failureMessage = failureMessage,
    this.resource = resource,
    this.line = line,
    this.charStart = charStart,
    this.charEnd = charEnd;
}


typedef void FailureMode(Failure failure);

FailureMode DEFAULT_FAILURE_MODE = STOP_ON_FAILURE;


final FailureMode IGNORE_FAILURE = (Failure failure) {
  if (failure.resource == null) {
    failure.project.logger.info(failure.failureMessage);
  } else {
    failure.project.logger.fileInfo(
        tool: failure.project.activeTarget.name,
        file: failure.resource,
        line: failure.line,
        charStart: failure.charStart,
        charEnd: failure.charEnd,
        message: failure.failureMessage);
  }
};

final FailureMode WARN_ON_FAILURE = (Failure failure) {
  if (failure.resource == null) {
    failure.project.logger.warn(failure.failureMessage);
  } else {
    failure.project.logger.fileInfo(
        tool: failure.project.activeTarget.name,
        file: failure.resource,
        line: failure.line,
        charStart: failure.charStart,
        charEnd: failure.charEnd,
        message: failure.failureMessage);
  }
};

FailureMode SET_PROPERTY_ON_FAILURE(String propertyName,
    [ String value = "true" ]) {
  FailureMode ret = (Failure failure) {
    failure.project.setProperty(propertyName, value);
  };
  return ret;
}

final FailureMode STOP_ON_FAILURE = (Failure failure) {
  if (failure == null) {
    throw new Exception("failure is null");
  }
  if (failure.project == null) {
    throw new Exception("failure project is null");
  }
  if (failure.project.activeTarget == null) {
    throw new Exception("activeTarget is null");
  }
  //throw new Exception("don't see anything wrong");
  throw new ToolException(
      failure.project.activeTarget,
      failure.resource == null ? null : failure.resource.relname,
      failure.line, failure.charStart,
      failure.charEnd, failure.failureMessage);
};



void handleFailure(Project project, {
    FailureMode mode: null,
    String failureMessage: null,
    Resource resource: null,
    int line: null,
    int charStart: null,
    int charEnd: null}) {
  if (mode == null) {
    mode = DEFAULT_FAILURE_MODE;
    if (mode == null) {
      // Bad setup, but we'll allow it.  Should report a warning, though.
      mode = STOP_ON_FAILURE;
    }
  }
  if (project == null) {
    // Bad tool - should always pass in the project
    throw new BuildSetupException(failureMessage);
  }
  var f = new Failure(project, failureMessage, resource: resource,
      line: line, charStart: charStart, charEnd: charEnd);
  mode(f);
}
