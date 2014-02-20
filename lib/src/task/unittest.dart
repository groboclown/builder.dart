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
library builder.src.task.unittest;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../../task.dart';



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
Future runSingleTest(Project proj, ResourceStreamable test,
    List<int> errorCounts, TestResultWriter resultWriter, List<String> testArgs,
    ResourceListable summaryDir) {
  var response = new ReceivePort();
  var streamc = new StreamController<LogMessage>.broadcast(sync: true);

  // This is tricky.  The isolate's main thread quits before the tests run,
  // because of the way that the unittest code is written (it spawns off the
  // tests after the main method finishes), while the isolate's Future returns
  // when the main thread completes.  To work around this, we need a way to
  // signal when the unittest is *really* complete.  Unfortunately, because
  // of the way that unittests may be async, this is far from trivial.

  // FIXME this currently hangs if the invoked isolate crashes before tests
  // run, such as due to compilation problems.  It also hangs if there are no
  // tests to run.

  // Looks like the Isolate should support microtasks, but there's an open
  // bug on it:
  // http://code.google.com/p/dart/issues/detail?id=14906
  // If that bug gets fixed, and this problem is still seen, then open a
  // new issue.  Changing the code if fixed would mean removing the special
  // message passing for notices on

  // Also of note, these bugs:
  // http://code.google.com/p/dart/issues/detail?id=15348
  // http://code.google.com/p/dart/issues/detail?id=15617


  var remote = Isolate.spawnUri(Uri.parse(test.relname),
      testArgs, response.sendPort)
    .then((_) => new Future(() => 1))
    .catchError((e, s) {
      proj.logger.error(e + "\n" + s.toString());
    });
  response.listen(
          (String msgStr) {
        var val = JSON.decode(msgStr);
        var msg = new LogMessage.fromJson(val);

        if (msg.createParams()['category'] == '<test-runner>' &&
            msg.message == "tests completed") {
          // special message that indicates the tests have completed
          response.close();
          return;
        }

        proj.logger.message(msg);
        if (msg.message_type == 'unittest') {
          var parms = msg.createParams();
          if (!parms['passed']) {
            errorCounts.add(1);
          }
        }
        streamc.add(msg);
      }, onDone: () {
        streamc.close();
      }
  );
  var fut = resultWriter(proj, summaryDir, test, streamc.stream);
  if (fut != null) {
    remote = Future.wait([remote, fut]);
  }
  return remote;
}



/**
 * Outputs messages to test result files.
 */
typedef Future TestResultWriter(Project project, DirectoryResource basedir,
    ResourceStreamable testFile, Stream<LogMessage> messages);


/**
 * Default writer.  Outputs test results to a JSon formatted file.
 */
final TestResultWriter JSON_TEST_RESULT_WRITER =
    (Project project, DirectoryResource basedir, ResourceStreamable testFile,
    Stream<LogMessage> messages) {
  List<Map> vals = [];
  ResourceStreamable outfile =
      basedir.child("testresult-" + testFile.name + ".json")
      as ResourceStreamable;
  Completer completer = new Completer.sync();
  messages.listen(
          (LogMessage msg) {
        vals.add(msg.toJson());
      },
      onDone: () {
        //print("*** completed tests for " + testFile.relname +
        //  ", received messages count: " + vals.length.toString());
        outfile.writeAsString(JSON.encode(vals));
        completer.complete();
      }
  );
  return completer.future;
};

