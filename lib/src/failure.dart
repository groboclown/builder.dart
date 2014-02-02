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


typedef void FailureMode(Project project, String failureMessage,
    Resource file, int line, int charStart, int charEnd);



final FailureMode IGNORE_FAILURES = (p, m, f, l, s, e) {
  if (f == null) {
    p.logger.info(m);
  } else {
    p.logger.fileInfo(
        tool: p.activeTarget.name,
        file: f,
        line: l,
        charStart: s,
        charEnd: e,
        message: m);
  }
};


