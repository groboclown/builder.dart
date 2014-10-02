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


const DEFAULT_TIMEOUT = 15;


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
    ResourceListable summaryDir,
    { ResourceListable runDir: null, Duration timeout: null }) {

  StreamController<LogMessage> streamc =
            new StreamController<LogMessage>.broadcast(sync: true);
  ReceivePort remoteMessages = new ReceivePort();
  ReceivePort remoteOnExit = new ReceivePort();
  ReceivePort remoteOnError = new ReceivePort();

  if (timeout == null) {
      timeout = new Duration(seconds: DEFAULT_TIMEOUT);
  }

  // Note: Windows Dart URI conversion requires forward slashes for
  // path separators.
  String relpath = test.relname.replaceAll("\\", "/");

  Future<Isolate> remote = Isolate.spawnUri(Uri.parse(relpath),
      testArgs, remoteMessages.sendPort, paused: true)
    .then((Isolate iso) {
      // These may not be supported
      try {
        iso.addOnExitListener(remoteOnExit.sendPort);
      } catch (_) {
        proj.logger.info("Dart implementation does not support Isolate.addOnExitListener");
      }
      try {
        iso.addErrorListener(remoteOnError.sendPort);
      } catch (_) {
          proj.logger.info("Dart implementation does not support Isolate.addErrorListener");
      }
      iso.resume(null);
    })
    .catchError((e, s) {
      proj.logger.error(e.toString() + "\n" + s.toString());
      if (! streamc.isClosed) {
          streamc.close();
      }
      remoteMessages.close();
    });

  new Timer(timeout, () {
      remote.then((Isolate iso) {
          try {
            iso.kill(1);
          } catch (_) {
              proj.logger.error("Problem terminating unit test");
          }
      });
  });

  remoteOnExit.listen((_) {
    if (! streamc.isClosed) {
        streamc.close();
    }
    remoteMessages.close();
  });

  remoteOnError.listen((List msg) {
    String err = "<unknown>";
    String stack = "";
    if (msg!= null && msg.length >= 2) {
        if (msg[0] != null) {
            err = msg[0].toString();
        }
        if (msg[1] != null) {
            stack = msg[1].toString();
        }
    }
    proj.logger.error(err + "\\n" + stack);
  });


  remoteMessages.listen(
          (String msgStr) {
        var val = JSON.decode(msgStr);
        var msg = new LogMessage.fromJson(val);

        if (msg.createParams()['category'] == '<test-runner>' &&
            msg.message == "tests completed") {
          // special message that indicates the tests have completed
          remoteMessages.close();
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
        if (! streamc.isClosed) {
          streamc.close();
        }
      }
  );
  var fut = resultWriter(proj, summaryDir, test, streamc.stream);
  return fut;
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

