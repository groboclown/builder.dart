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

import 'dart:isolate';
export 'dart:isolate' show SendPort;

import 'package:unittest/unittest.dart';
export 'package:unittest/unittest.dart';

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


import 'src/logger.dart';


class BuilderConfiguration extends SimpleConfiguration {
  BuilderConfiguration(SendPort replyTo) {
    print("start builder");
    // FIXME

    throwOnTestFailures = false;
  }

  @override
  void onInit() {
    print("onInit");
    super.onInit();
    filterStacks = formatStacks = true;
  }

  @override
  void onTestStart(TestCase testCase) {
    super.onTestStart(testCase);

    // FIXME send log message
    print("onTestStart " + testCase.description);
  }

  @override
  void onTestResult(TestCase testCase) {
    print("onTestResult " + testCase.description);
    super.onTestResult(testCase);

    // FIXME send log message
  }

  /**
   * Called when an already completed test changes state. For example: a test
   * that was marked as passing may later be marked as being in error because
   * it still had callbacks being invoked.
   */
  @override
  void onTestResultChanged(TestCase testCase) {
    print("onTestResultChanged " + testCase.description);
    super.onTestResultChanged(testCase);

    // FIXME send log message
  }

  /**
   * Handles the logging of messages by a test case.
   */
  @override
  void onLogMessage(TestCase testCase, String message) {
    // FIXME send log message
    print("onLogMessage " + testCase.description + "[" + message + "]");
  }

  /**
   * Called when the unittest framework is done running. [success] indicates
   * whether all tests passed successfully.
   */
  @override
  void onDone(bool success) {
    print("onDone " + success);
    super.onDone(success);

    // FIXME send log message
    // FIXME close port
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

    // FIXME send actual test result message

    // Things to output (see TestCase):
    // result.id;
    // result.description;
    // result.message;
    // result.result;
    // result.passed;
    // result.stackTrace;
    // result.currentGroup;
    // result.startTime;
    // result.runningTime;
  }

}


void selectConfiguration(SendPort replyTo, [ void useAlternateConfig() ]) {
  if (replyTo != null) {
    unittestConfiguration = new BuilderConfiguration(replyTo);
  } else if (useAlternateConfig != null) {
    useAlternateConfig();
  }
}
