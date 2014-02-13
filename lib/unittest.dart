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

library builder.unittest;

import 'dart:convert';

import 'dart:isolate';
export 'dart:isolate' show SendPort;

import 'package:unittest/unittest.dart';
export 'package:unittest/unittest.dart';

import 'src/logger.dart' as logger;

/**
 * Runs in an isolate while the real build waits.  This communicates with
 * the real build.  Sends [LogMessage] instances back to the spawner.
 *
 * Test classes that use this need to follow this format:
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
 * If your tests want a specific output format for when you run without
 * the builder, you can setup your build like this:
 *
 *     import 'package:builder/unittest.dart';
 *     import 'package:unittest/vm_config.dart';
 *
 *     main(List<String> args, [ SendPort replyTo ]) {
 *       selectConfiguration(replyTo, useVMConfiguration);
 *
 *       test( "my test", () {
 *         // ...
 *       });
 *     }
 */


class BuilderConfiguration extends SimpleConfiguration {
  final SendPort _replyTo;

  BuilderConfiguration(this._replyTo) {
    //print("BuilderConfiguration()");
    throwOnTestFailures = false;
  }

  @override
  void onInit() {
    //print("onInit");
    super.onInit();
    filterStacks = formatStacks = true;
  }

  @override
  void onTestStart(TestCase testCase) {
    super.onTestStart(testCase);

    //print("onTestStart " + testCase.description);
    _log(testCase.description, testCase.description + " running");
  }

  @override
  void onTestResult(TestCase testCase) {
    //print("onTestResult " + testCase.description);
    super.onTestResult(testCase);

    _log(testCase.description, testCase.description + " completed");
  }

  /**
   * Called when an already completed test changes state. For example: a test
   * that was marked as passing may later be marked as being in error because
   * it still had callbacks being invoked.
   */
  @override
  void onTestResultChanged(TestCase testCase) {
    //print("onTestResultChanged " + testCase.description);
    super.onTestResultChanged(testCase);

    _log(testCase.description, testCase.description + " updated");
  }

  /**
   * Handles the logging of messages by a test case.
   */
  @override
  void onLogMessage(TestCase testCase, String message) {
    //print("onLogMessage " + testCase.description + "[" + message + "]");
    _log(testCase.description, message);
  }

  /**
   * Called when the unittest framework is done running. [success] indicates
   * whether all tests passed successfully.
   */
  @override
  void onDone(bool success) {
    //print("onDone " + success.toString());
    super.onDone(success);

    _log("<test-runner>", "tests completed");
    // NOTE no way to explicitly close the port
  }

  /**
   * Called with the result of all test cases. Browser tests commonly override
   * this to reformat the output.
   *
   * When [uncaughtError] is not null, it contains an error that occured outside
   * of tests (e.g. setting up the test).
   */
  @override
  void onSummary(int passed, int failed, int errors, List<TestCase> results,
      String uncaughtError) {
    //print("onSummary(${passed}, ${failed}, ${errors}, ${results}, ${uncaughtError})");

    _log("<test-runner>", "Tests completed: " + passed.toString() +
      " passed, " + failed.toString() + " failed, " + errors.toString() +
      " errors", (failed + errors > 0) ? logger.ERROR : logger.INFO);
    if (uncaughtError != null) {
      _log("uncaught error", uncaughtError, logger.ERROR);
    }


    for (TestCase test in results) {
      _send(new LogUnitTestMessage(test));
    }
  }



  void _log(String from, String message, [ String level = logger.INFO ]) {
    _send(new logger.LogToolMessage(level: level, tool: "unittest",
        category: from, id: from, message: message));
  }

  void _send(logger.LogMessage msg) {
    //print("sending " + msg.toJson().toString());
    try {
      _replyTo.send(JSON.encode(msg.toJson()));
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  String _tcName(TestCase tc) {
    var ret = tc.description;
    if (tc.currentGroup != null && tc.currentGroup.length > 0) {
      ret += " (" + tc.currentGroup + ")";
    }
    if (tc.message != null) {
      ret += ": " + tc.message;
    }
    return ret;
  }
}


void selectConfiguration(SendPort replyTo, [ void useAlternateConfig() ]) {
  if (replyTo != null) {
    unittestConfiguration = new BuilderConfiguration(replyTo);
  } else if (useAlternateConfig != null) {
    useAlternateConfig();
  }
}



/**
 * A container structure for logging a message about a unit test
 */
class LogUnitTestMessage extends logger.LogToolMessage {
  final int testId;
  final String testDescription;
  final String testFailureMessage;
  final bool testPassed;
  final String testResult;
  final StackTrace testFailureTrace;
  final DateTime testStartTime;
  final Duration testRunTime;
  final String testGroup;


  LogUnitTestMessage(TestCase testCase) :
    testId = testCase.id,
    testDescription = testCase.description,
    testFailureMessage = testCase.message,
    testPassed = testCase.passed,
    testResult = testCase.result,
    testFailureTrace = testCase.stackTrace,
    testStartTime = testCase.startTime,
    testRunTime = testCase.runningTime,
    testGroup = testCase.currentGroup,
    super(level: (testCase.passed ? logger.INFO : logger.ERROR),
        tool: "unittest", category: "test", id: "UNKNOWN",
        message: testCase.description + " " + (testCase.passed ? "passed" : testCase.message),
        message_type: "unittest");

  @override
  Map<String, dynamic> createParams() {
    // FIXME make this more robust in the future
    var trace = testFailureTrace.toString();

    var params = super.createParams();
    params.addAll(<String, dynamic>{
        "id": testId,
        "description": testDescription,
        "failureMessage": testFailureMessage,
        "passed": testPassed,
        "result": testResult,
        "failureTrace": trace,
        "startTime": testStartTime.toString(), // FIXME
        "runingTime": testRunTime.toString(), // FIXME
        "testGroup": testGroup
    });
    return params;
  }

}
