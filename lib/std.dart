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

library builder.std;

/**
 * Standard build constants for the normal dart project layout, based on
 * (package layout conventions)[http://pub.dartlang.org/doc/package-layout.html].
 */

import 'src/resource.dart';
import 'tool.dart';
export 'tool.dart' show Pipe;

import 'dart:io';
import 'dart:async';

ResourceTest DART_FILE_FILTER = (r) =>
  (r.exists && DEFAULT_IGNORE_TEST(r) && r.name.toLowerCase().endsWith(".dart"));


final DirectoryResource ASSET_DIR = new FileEntityResource.asDir("asset");
final ResourceCollection ASSET_FILES = ASSET_DIR.asCollection(
    resourceTest: DEFAULT_IGNORE_TEST, recurseTest: DEFAULT_IGNORE_TEST);

final DirectoryResource BENCHMARK_DIR = new FileEntityResource.asDir("benchmark");
final ResourceCollection BENCHMARK_FILES = BENCHMARK_DIR.asCollection(
    resourceTest: DART_FILE_FILTER, recurseTest: SOURCE_RECURSION_TEST);

final DirectoryResource BIN_DIR = new FileEntityResource.asDir("bin");
final ResourceCollection BIN_FILES = BIN_DIR.asCollection(
    resourceTest: DEFAULT_IGNORE_TEST, recurseTest: SOURCE_RECURSION_TEST);

final DirectoryResource DOC_DIR = new FileEntityResource.asDir("doc");
final ResourceCollection DOC_FILES = BIN_DIR.asCollection(
    resourceTest: DEFAULT_IGNORE_TEST, recurseTest: DEFAULT_IGNORE_TEST);

final DirectoryResource EXAMPLE_DIR = new FileEntityResource.asDir("example");
final ResourceCollection EXAMPLE_FILES = EXAMPLE_DIR.asCollection(
    resourceTest: DEFAULT_IGNORE_TEST, recurseTest: SOURCE_RECURSION_TEST);

final DirectoryResource LIB_DIR = new FileEntityResource.asDir("lib");
final ResourceCollection LIB_FILES = LIB_DIR.asCollection(
    resourceTest: DART_FILE_FILTER, recurseTest: SOURCE_RECURSION_TEST);

final DirectoryResource TEST_DIR = new FileEntityResource.asDir("test");
final ResourceCollection TEST_FILES = TEST_DIR.asCollection(
    resourceTest: DART_FILE_FILTER, recurseTest: SOURCE_RECURSION_TEST);

final DirectoryResource TOOL_DIR = new FileEntityResource.asDir("tool");
final ResourceCollection TOOL_FILES = TOOL_DIR.asCollection(
    resourceTest: DEFAULT_IGNORE_TEST, recurseTest: SOURCE_RECURSION_TEST);

final DirectoryResource WEB_DIR = new FileEntityResource.asDir("web");
final ResourceCollection WEB_FILES = WEB_DIR.asCollection(
    resourceTest: DEFAULT_IGNORE_TEST, recurseTest: DEFAULT_IGNORE_TEST);


final ResourceCollection DART_FILES = new ResourceSet.from([
    BENCHMARK_FILES, BIN_FILES, DOC_FILES, EXAMPLE_FILES, LIB_FILES,
    TEST_FILES, TOOL_FILES
]);




// ---------------------------------------------------------------------------
// Standard Targets



/**
 *
 */
class Delete extends BuildTool {
  final ResourceCollection _files;
  final FailureMode onFailure;

  factory Delete(String name,
      { String description: "", String phase: PHASE_CLEAN,
      ResourceCollection files: null, List<String> depends: null,
      FailureMode onFailure: null }) {
    if (depends == null) {
      depends = <String>[];
    }

    // Because this is a Clean, this does not really take files as input.
    var pipe = new Pipe.list(null, null);
    var targetDef = BuildTool
      .mkTargetDef(name, description, phase, pipe, depends, <String>[]);
    return new Delete._(name, targetDef, phase, pipe, files, onFailure);

  }


  Delete._(String name, target targetDef, String phase, Pipe pipe,
      ResourceCollection files, FailureMode onFailure) :
      this._files = files, this.onFailure = onFailure,
      super(name, targetDef, phase, pipe);


  @override
  Future<Project> start(Project project) {
    var inp = _files.entries();
    if (inp.isEmpty) {
      project.logger.info("nothing to do");
      return new Future<Project>.sync(() => project);
    }

    return new Future<Project>.sync(() {
      var problems = <Resource>[];
      for (Resource r in inp) {
        if (r.exists) {
          if (! r.delete(false)) {
            problems.add(r);
          }
        }
      }
      if (problems.isNotEmpty) {
        handleFailure(project,
          mode: onFailure,
          failureMessage: "could not remove the following files: " +
            problems.toString());
      }
      return new Future<Project>.sync(() => project);
    });
  }
}


/**
 * For the most part, this is automatically performed.  However, there are some
 * circumstances where the build requires the creation of an empty directory.
 */
class MkDir extends BuildTool {
  final FailureMode onFailure;

  factory MkDir(String name,
                 { String description: "", String phase: PHASE_BUILD,
                 Resource dir: null, List<String> depends: null,
                 FailureMode onFailure: null }) {
    if (depends == null) {
      depends = <String>[];
    }

    // This generates a resource without any input
    var pipe = new Pipe.list(null, <Resource>[ dir ]);
    var targetDef = BuildTool
      .mkTargetDef(name, description, phase, pipe, depends, <String>[]);
    return new MkDir._(name, targetDef, phase, pipe, onFailure);
  }


  MkDir._(String name, target targetDef, String phase, Pipe pipe,
           FailureMode onFailure) :
    this.onFailure = onFailure,
    super(name, targetDef, phase, pipe);


  @override
  Future<Project> start(Project project) {
    var out = pipe.output;
    if (out.isEmpty) {
      project.logger.info("nothing to do");
      return new Future<Project>.sync(() => project);
    }

    var problems = <Resource>[];
    Future ret = null;
    for (Resource r in out) {
      if (! r.exists && r is DirectoryResource) {
        if (ret != null) {
          ret = (r.entity as Directory).create(recursive: true).
            catchError((error) {
              problems.add(r);
            });
        } else {
          ret = ret.then((_) => (r.entity as Directory).create(recursive: true).
            catchError((error) {
              problems.add(r);
            }));
        }
      }
    }
    if (ret == null) {
      project.logger.info("nothing to do");
      return new Future<Project>.sync(() => project);
    }

    ret.then((_) {
      if (problems.isNotEmpty) {
        handleFailure(project,
          mode: onFailure,
          failureMessage: "could not create the following directories: " +
            problems.toString());
      }
      return project;
    });
  }
}


/**
 * Runs a process.
 */
class Exec extends BuildTool {
  final FailureMode onErrorLaunching;
  final FailureMode onFailure;

  final DirectoryResource workingDir;
  final FileResource cmd;
  final List<String> args;
  final Map<String, String> env;
  final bool includeParentEnvironment;

  final bool runInShell;

  final FileResource stdinSrc;
  final FileResource stdoutSrc;
  final FileResource stderrSrc;
  final bool pipeStderrToStdout;
  final bool stdoutAppend;
  final bool stderrAppend;




  factory Exec(String name,
      { String description: "", String phase: PHASE_BUILD,
      Iterable<String> depends: null,

      DirectoryResource workingDir: null, FileResource cmd: null,
      Pipe affectedFiles,
      Iterable<String> args: null, Map<String, String> env,
      bool includeParentEnvironment: true,
      bool runInShell: false, FileResource stdin, FileResource stdout,
      FileResource stderr, bool pipeStderrToStdout,
      bool stdoutAppend: false, bool stderrAppend: false,
      FailureMode onErrorLaunching: null,
      FailureMode onFailure: null }) {
    if (depends == null) {
      depends = <String>[];
    }

    if (args == null) {
      args = <String>[];
    }

    // Create the correct mappings.
    var requiredInput = <Resource>[];
    var requiredOutput = <Resource>[];
    var optionalInput = <Resource>[];
    var directPipe = <Resource, Iterable<Resource>>{};

    if (affectedFiles != null) {
      requiredInput.addAll(affectedFiles.requiredInput);
      optionalInput.addAll(affectedFiles.optionalInput);
      requiredOutput.addAll(affectedFiles.output);
      directPipe.putAll(affectedFiles.directPipe);
    }

    if (workingDir != null && ! workingDir.exists) {
      requiredInput.add(workingDir);
    }

    if (! cmd.exists) {
      requiredInput.add(cmd);
    }

    if (stdin != null) {
      requiredInput.add(stdin);
    }
    if (stdout != null) {
      requiredOutput.add(stdout);
    }
    if (stderr != null) {
      assert(pipeStderrToStdout == false);
      requiredOutput.add(stderr);
    }

    var allInput = new List<Resource>.from(requiredInput);
    allInput.addAll(optionalInput);
    for (var inp in allInput) {
      for (var out in [ stdout, stderr ]) {
        if (out != null) {
          if (directPipe[inp] == null) {
            directPipe[inp] = <Resource>[];
          }
          directPipe[inp].add(out);
        }
      }
    }


    var pipe = new Pipe.all(
      requiredInput: requiredInput,
      optionalInput: optionalInput,
      output: requiredInput,
      directPipe: directPipe);
    var targetDef = BuildTool
      .mkTargetDef(name, description, phase, pipe, depends, <String>[]);
    return new Exec._(name, targetDef, phase, pipe,
      workingDir, cmd, args, env, includeParentEnvironment, runInShell,
      stdin, stdout, stderr, pipeStderrToStdout, stdoutAppend, stderrAppend,
      onErrorLaunching, onFailure);
  }


  Exec._(String name, target targetDef, String phase, Pipe pipe,
      DirectoryResource workingDir, FileResource cmd,
      Iterable<String> args, Map<String, String> env,
      bool includeParentEnvironment,
      bool runInShell, FileResource stdin, FileResource stdout,
      FileResource stderr, bool pipeStderrToStdout,
      bool stdoutAppend, bool stderrAppend,
      FailureMode onErrorLaunching, FailureMode onFailure) :
    this.workingDir = workingDir,
    this.cmd = cmd,
    this.args = args,
    this.env = env,
    this.includeParentEnvironment = includeParentEnvironment,
    this.runInShell = runInShell,
    this.stdinSrc = stdin,
    this.stdoutSrc = stdout,
    this.stderrSrc = stderr,
    this.stdoutAppend = stdoutAppend,
    this.stderrAppend = stderrAppend,
    this.pipeStderrToStdout = pipeStderrToStdout,
    this.onErrorLaunching = onErrorLaunching,
    this.onFailure = onFailure,
    super(name, targetDef, phase, pipe);



  @override
  Future<Project> start(Project project) {
    project.logger.debug("Running [" + cmd.relname + "] with arguments " +
      args.toString());

    return Process.start(cmd.absolute, args,
        workingDirectory: (workingDir == null ? null : workingDir.absolute),
        environment: env,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell).then((Process process) {

      var futures = <Future>[];
      var pout = process.stdout;

      if (pipeStderrToStdout) {
        pout = new StreamController<List<int>>.broadcast();
        pout.addStream(process.stdout);
        pout.addStream(process.stderr);
      }
      if (stdoutSrc != null) {
        futures.add(pipeStream(pout, stdoutSrc, stdoutAppend));
      } else {
        stdout.addStream(process.stdout);
      }
      if (stderrSrc != null) {
        futures.add(pipeStream(process.stderr, stderrSrc, stderrAppend));
      } else if (! pipeStderrToStdout) {
        stderr.addStream(process.stderr);
      }
      if (stdinSrc != null) {
        var finished = new Completer.sync();
        try {
          Stream<List<int>> inp = stdinSrc.openRead();
          finished = pipeStreamSink(finished, inp, process.stdin);
        } catch (e, s) {
          finished = finished.future.completeError(e, s);
        }
        futures.add(finished);
      }

      if (futures.isNotEmpty) {
        return Future.wait(futures).then((_) => process.exitCode);
      } else {
        return process.exitCode;
      }

    }).then((int code) {
      project.logger.info("Completed " + cmd.relname + " with exit code " +
        code.toString());
      if (code != 0 && onFailure != null) {
        handleFailure(project,
          mode: onFailure,
          failureMessage: cmd.relname + " exited with " + code.toString(),
          resource: cmd);
      }
      return new Future.value(project);
    });
  }



  Future pipeStream(Stream<List<int>> inp, FileResource out, bool append) {
    var finished = new Completer.sync();
    try {
      IOSink outsink = out.openWrite(mode: append
        ? FileMode.APPEND : FileMode.WRITE);
      return pipeStreamSink(finished, inp, outsink);
    } catch (e, s) {
      finished.completeError(e, s);
      return finished;
    }
  }


  Future pipeStreamSink(Completer finished, Stream<List<int>> inp,
      IOSink outsink) {
    // We aren't using addStream so that we can correctly catch the
    // onDone from the stream.

    inp.listen(
            (data) {
          try {
            outsink.add(data);
          } catch (e, s) {
            outsink.close().then((_) => finished.completeError(e, s));
          }
        }, onDone: () {
          outsink.close()
          .then((_) => finished.complete() )
          .catchError((e, s) => finished.completeError(e, s));
        }, onError: (e, s) {
          outsink.close().then((_) => finished.completeError(e, s));
        }
    );
    return finished.future;
  }

}
