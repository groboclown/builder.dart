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
//import 'dart:isolate';
import 'dart:io';

import '../../task.dart';
import '../dart_path.dart';
import '../os.dart';


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
 *       setConfiguration(args, replyTo);
 *
 *       test( "my test", () {
 *         // ...
 *       });
 *     }
 *
 * The tests don't need to be in the `main` method, but the execution of
 * `setConfiguration(replyTo)` _must_ be there if you want to have the unit test
 * populate the test output directory correctly.
 *
 * Also, each test dart file *must* include at least one test, or the build will
 * hang indefinitely.  FIXME check if this is still true.
 */
Future runSingleTest(Project proj, ResourceStreamable test,
    List<int> errorCounts, TestResultWriter resultWriter, List<String> testArgs,
    ResourceListable summaryDir,
    { TargetMethod activeTarget, ResourceListable runDir: null,
    Duration timeout: null, String cmd, Logger logger }) {
  if (cmd == null) {
    cmd = DART_NAME;
  }

  StreamController<String> sout = new StreamController<String>();
  sout.stream.transform(new LineSplitter()).listen((String msg) {
      logger.info(msg);
  });
  StreamController<LogMessage> streamc =
            new StreamController<LogMessage>.broadcast(sync: true);
  resultWriter(proj, summaryDir, test, streamc.stream);

  Resource exec = resolveExecutable(cmd, DART_PATH);
  if (exec == null) {
    throw new BuildExecutionException(activeTarget,
    "could not find " + cmd);
  }

  var args = <String>['-c'];
  args.add(test.absolute);
  args.add('--json');

  logger.debug("Running [" + exec.relname + "] with arguments " +
    args.toString());

  return Process.start(exec.relname, args, workingDirectory: runDir.relname)
    .then((process) {
      StringBuffer jsonData = new StringBuffer();
      process.stderr.transform(new Utf8Decoder(allowMalformed: true))
        .transform(new LineSplitter()).listen((String line) {
          logger.warn(line);
        });
      process.stdout.transform(new Utf8Decoder(allowMalformed: true))
        .listen((String data) {
          jsonData.write(data);
          String js = jsonData.toString();
          int pos1 = js.indexOf('#@%');
          int pos2 = js.indexOf('%@#');
          if (pos1 >= 0 && pos2 > pos1 + 3) {
              sout.add(js.substring(0, pos1));
              String msgStr = js.substring(pos1 + 3, pos2);
              String rest =
                      js.length < pos2 + 3
                          ? js.substring(pos2 + 3)
                          : "";
              jsonData.clear();
              jsonData.write(rest);

              var val = JSON.decode(msgStr);
              var msg = new LogMessage.fromJson(val);

              if (msg.createParams()['category'] == '<test-runner>' &&
                  msg.message == "tests completed") {
                // special message that indicates the tests have completed
                streamc.close();
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
          }
        }, onDone: () {
          // no new data, so no need to check for json strings
          sout.add(jsonData.toString());
          sout.close();
          jsonData = null;
          streamc.close();
        });
    return process.exitCode;
  }).then((code) {
    if (code != 0) {
      logger.fileError(
        file: test,
        category: "test-runner",
        message: "Tests failed in " + test.name);
    } else {
      logger.fileInfo(
        file: test,
        category: "test-runner",
        message: "Tests succeeded in " + test.name);
    }
  });
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

