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

library builder.dart;

/**
 * Methods to invoke the commands distributed with the dart sdk.
 */

import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

import 'src/resource.dart';
import 'tool.dart';
import 'src/logger.dart';

import 'src/tool/dartanalyzer.dart';
export 'src/tool/dartanalyzer.dart' show
  dartAnalyzer;

final List<String> DART_PATH = <String>[
    (Platform.environment['DART_SDK'] == null
        ? null
        : Platform.environment['DART_SDK'] + "/bin"),
    (Platform.environment['DART_HOME'] == null
        ? null
        : Platform.environment['DART_HOME'] + "/bin" )];
final String DART_ANALYZER_NAME = "dartanalyzer";



/**
 * Build tool for running the `dartanalysis` tool on a set of input files.
 * It takes the following arguments, in addition to the normal build tool
 * arguments:
 *
 * * `cmd` ([String]) - the actual command to run.  By default, this is
 *  found using the `DART_HOME` or `DART_SDK` environment variable, under
 *  the `bin/dartanalyzer` name.
 * * `dartFiles` ([ResourceSet]) - all the files to analyze.  For each file
 *  in this set, the analyzer will be called once.  This most probably will
 *  cause the analyzer to check the same file multiple times, so you can
 *  optimize your build to just include the entry files.  For safety, this
 *  can just be every dart file, but will run slower.
 * * `packageRoot` ([DirectoryResource]) - the "packages" directory.  If
 *  not specified, then this uses the "packages" directory where the build
 *  file is located (the "current directory").
 * * `onFailure` ([FailureMode]) - how to handle a failure message from the
 *  analyzer.  Default is to quit the build with an error.
 * * `onWarning` ([FailureMode]) - how to handle a warning message from the
 *  analyzer.  Default is to log the message, but keep the build running.
 * * `onInfo` ([FailureMode]) - how to handle an info message from the
 *  analyzer.  Default is to log the message, but keep the build running.
 *
 * **Normal Example:**
 *
 *     final dartAnalyzer = new DartAnalyzer("lint",
 *         description: "Check the Dart files for language issues",
 *         dartFiles: DART_FILES);
 *
 * Creates a dart analyzer target named "lint", using the default (not
 * specified) package root, and run on all files in the `DART_FILES`
 * [ResourceSet].  It will fail the build if the dart analyzer reports
 * failures.  It will not fail the build on warning or info messages.
 */
class DartAnalyzer extends BuildTool {
  final String cmd;
  final DirectoryResource packageRoot;
  final FailureMode onFailure;
  final FailureMode onWarning;
  final FailureMode onInfo;

  factory DartAnalyzer(String name,
      { String description: "", String phase: PHASE_BUILD,
        ResourceCollection dartFiles: null, List<String> depends: null,
        DirectoryResource packageRoot: null,
        String cmd: null, FailureMode onFailure: null,
        FailureMode onWarning: null, FailureMode onInfo: null }) {
    if (depends == null) {
      depends = <String>[];
    }
    
    var pipe = new Pipe.list(dartFiles.entries(), <Resource>[]);
    var targetDef = BuildTool
      .mkTargetDef(name, description, phase, pipe, depends, <String>[]);
    return new DartAnalyzer._(name, targetDef, phase, pipe, cmd, packageRoot,
      onFailure, onWarning, onInfo);
  }


  DartAnalyzer._(String name, target targetDef, String phase, Pipe pipe,
    String cmd, DirectoryResource packageRoot, FailureMode onFailure,
    FailureMode onWarning, FailureMode onInfo) :
    this.cmd = cmd, this.packageRoot = packageRoot,
    this.onFailure = onFailure, this.onWarning = onWarning,
    this.onInfo = onInfo,
    super(name, targetDef, phase, pipe);


  @override
  Future<Project> start(Project project) {
    var inp = new List<Resource>.from(pipe.requiredInput);
    inp.addAll(pipe.optionalInput);

    if (inp.isEmpty) {
      project.logger.info("nothing to do");
      return new Future<Project>.sync(() => project);
    }

    var uniqueLines = new Set<String>();

    var hadWarnings = false;
    var hadErrors = false;
    var hadInfo = false;
    StreamController<LogMessage> messages = new StreamController<LogMessage>();
    messages.stream.listen((LogMessage msg) {
      if (msg.level.startsWith("warn")) {
        hadWarnings = true;
      }
      if (msg.level.startsWith("err")) {
        hadErrors = true;
      }
      if (msg.level.startsWith("info")) {
        hadInfo = true;
      }
    });


    // Chain the calls, rather than running in parallel.
    // For running in parallel, we create all the Futures in the
    // calls to dartAnalyzer, then return a Future.wait() on all of them.
    Future ret = null;
    for (Resource r in inp) {
      if (r.exists && ! (r is ResourceListable)) {
        Future next(_) {
          return dartAnalyzer(r, project.logger, messages,
            packageRoot: packageRoot, cmd: cmd,
            uniqueLines: uniqueLines,
            activeTarget: project.activeTarget);
        }
        if (ret == null) {
          ret = next(project);
        } else {
          ret = ret.then(next);
        }
      }
    }
    ret = ret.then((_) {
      messages.close();
      if (hadErrors) {
        handleFailure(project,
            mode: onFailure,
            failureMessage: "one or more files had errors");
      }
      if (hadWarnings && onWarning != null) {
        handleFailure(project,
            mode: onWarning,
            failureMessage: "one or more files had warnings");
      }
      if (hadInfo && onInfo != null) {
        handleFailure(project,
            mode: onInfo,
            failureMessage: "one or more files had info messages");
      }
      return new Future<Project>.sync(() => project);
    });
    return ret;
  }
}




/**
 * Outputs messages to test result files.
 */
typedef Future TestResultWriter(Project project, DirectoryResource basedir,
    Resource testFile, Stream<LogMessage> messages);


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
        return runSingleTest(project, r, errorCounts);
      }
      if (runner == null) {
        runner = next(project);
      } else {
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


  Future runSingleTest(Project proj, Resource test, List<int> errorCounts) {
    var response = new ReceivePort();
    var streamc = new StreamController<LogMessage>.broadcast(sync: true);

    // This is tricky.  The isolate's main thread quits before the tests run,
    // because of the way that the unittest code is written (it spawns off the
    // tests after the main method finishes), while the isolate's Future returns
    // when the main thread completes.  To work around this, we need a way to
    // signal when the unittest is *reallY* complete.  Unfortunately, because
    // of the way that unittests may be async, this is far from trivial.


    var remote = Isolate.spawnUri(Uri.parse(test.relname),
        testArgs, response.sendPort)
      .then((_) => new Future(() => 1 ))
      .catchError((e, s) { proj.logger.error(e + "\n" + s.toString()); });
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
            if (! parms['passed']) {
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

}

final TestResultWriter JSON_TEST_RESULT_WRITER =
    (Project project, DirectoryResource basedir, Resource testFile,
    Stream<LogMessage> messages) {
  List<Map> vals = [];
  Resource outfile = basedir.child("testresult-" + testFile.name + ".json");
  Completer completer = new Completer.sync();
  messages.listen(
    (LogMessage msg) {
      vals.add(msg.toJson());
    },
    onDone: () {
      //print("*** completed tests for " + testFile.relname + ", received messages count: " + vals.length.toString());
      outfile.writeAsString(JSON.encode(vals));
      completer.complete();
    }
  );
  return completer.future;
};


