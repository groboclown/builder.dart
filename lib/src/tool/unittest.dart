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
 * Executes unittest files as an Isolate.
 */
library builder.src.tool.unittest;

import 'dart:async';

import '../task/unittest.dart';
import '../../tool.dart';



/**
 * Build tool for running unit tests, with the `unittest` dart package.
 * This tool has some requirements that must be met in the test files in order
 * for it to be used.
 *
 * First, the test files must follow this format:
 *
 *     import 'package:builder/unittest.dart';
 *
 *     main(List<String> args, [ SendPort replyTo ]) {
 *       selectConfiguration(replyTo);
 *
 *       test( "my test", () {
 *         // ...
 *       });
 *     }
 *
 * The tests don't need to be in the `main` method, but the execution of
 * `selectConfiguration(replyTo)` _must_ be there for the unittest package to
 * correctly communicate back to the build.
 *
 * Also, each test dart file *must* include at least one test, or the build will
 * hang indefinitely.
 *
 *
 */

class UnitTests extends BuildTool {
  final FailureMode onFailure;

  final ResourceListable summaryDir;

  final List<String> testArgs;

  final TestResultWriter resultWriter;



  factory UnitTests(String name,
      { String description: "", String phase: PHASE_BUILD,
      ResourceCollection testFiles: null, ResourceListable summaryDir: null,
      List<String> depends: null, List<String> testArgs: null,
      FailureMode onFailure: null, TestResultWriter resultWriter }) {
    if (depends == null) {
      depends = <String>[];
    }

    if (resultWriter == null) {
      resultWriter = JSON_TEST_RESULT_WRITER;
    }
    if (testArgs == null) {
      testArgs = <String>[];
    }

    var resultMap = <Resource, List<Resource>>{};
    testFiles.entries().forEach((Resource f) {
      resultMap[f] = <Resource>[summaryDir.child("result-" + f.name + ".json")];
    });

    var pipe = new Pipe.direct(resultMap);
    var targetDef = BuildTool
      .mkTargetDef(name, description, phase, pipe, depends, <String>[]);
    return new UnitTests._(name, targetDef, phase, pipe, summaryDir,
      testArgs, onFailure, resultWriter);
  }


  UnitTests._(String name, target targetDef, String phase, Pipe pipe,
      ResourceListable summaryDir, List<String> testArgs, FailureMode onFailure,
      TestResultWriter resultWriter) :
    this.summaryDir = summaryDir, this.onFailure = onFailure,
    this.testArgs = testArgs, this.resultWriter = resultWriter,
    super(name, targetDef, phase, pipe);



  @override
  Future<Project> start(Project project) {
    var inp = new List<Resource>.from(pipe.requiredInput);
    inp.addAll(pipe.optionalInput);
    if (inp.isEmpty) {
      project.logger.info("nothing to do");
      return new Future<Project>.sync(() => project);
    }
    project.logger.debug("tests to run: " + inp.toString());

    var errorCounts = <int>[];
    Future runner = null;
    for (Resource r in inp) {
      Future next(_) {
        project.logger.info("Running test file " + r.name);
        return runSingleTest(project, r, errorCounts, resultWriter,
            testArgs, summaryDir);
      }
      if (runner == null) {
        runner = next(project);
      }
      else {
        runner = runner.then(next);
      }
    }

    return runner
    .then((_) {
      if (errorCounts.fold(0, (prev, element) => prev + element) > 0) {
        handleFailure(project,
        mode: onFailure,
        failureMessage: "one or more tests had errors");
      }
      return new Future<Project>.sync(() => project);
    });
  }

}


