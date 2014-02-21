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

library builder.src.tool.exec;

/**
 * Standard build constants for the normal dart project layout, based on
 * (package layout conventions)[http://pub.dartlang.org/doc/package-layout.html].
 */

import '../../tool.dart';

import 'dart:io';
import 'dart:async';




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

  final Set<String> platforms;




  factory Exec(String name,
      { String description: "", String phase: PHASE_BUILD,
      Iterable<String> depends: null,

      DirectoryResource workingDir: null, FileResource cmd: null,
      Pipe affectedFiles,
      Iterable<String> args: null, Map<String, String> env,
      bool includeParentEnvironment: true,
      bool runInShell: false, FileResource stdin, FileResource stdout,
      FileResource stderr, bool pipeStderrToStdout: false,
      bool stdoutAppend: false, bool stderrAppend: false,
      FailureMode onErrorLaunching: null,
      FailureMode onFailure: null,
      String platform: null, List<String> platforms: null }) {
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
      directPipe.addAll(affectedFiles.directPipe);
    }

    if (workingDir != null && ! workingDir.exists) {
      requiredInput.add(workingDir);
    }

    // cmd could be null if the platform isn't a match.

    if (cmd != null && ! cmd.exists) {
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

    var plats = new Set<String>();
    if (platforms != null) {
      plats.addAll(platforms.map((p) => p.toLowerCase()));
    }
    if (platform != null) {
      plats.add(platform.toLowerCase());
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
      onErrorLaunching, onFailure, plats);
  }


  Exec._(String name, TargetDef targetDef, String phase, Pipe pipe,
      DirectoryResource workingDir, FileResource cmd,
      Iterable<String> args, Map<String, String> env,
      bool includeParentEnvironment,
      bool runInShell, FileResource stdin, FileResource stdout,
      FileResource stderr, bool pipeStderrToStdout,
      bool stdoutAppend, bool stderrAppend,
      FailureMode onErrorLaunching, FailureMode onFailure,
      Set<String> platforms) :
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
    this.platforms = platforms,
    super(name, targetDef, phase, pipe);



  @override
  Future start(Project project) {
    if (platforms.isNotEmpty &&
        ! platforms.contains(Platform.operatingSystem.toLowerCase())) {
      project.logger.info("Cannot run " +
        (cmd == null ? name : cmd.relname) + " on this operating system");
      return null;
    }

    if (! cmd.exists) {
      throw new BuildExecutionException(project.activeTarget,
        "Could not find command " + cmd.relname);
    }

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
        var completer = new Completer.sync();
        Future finished = null;
        try {
          Stream<List<int>> inp = stdinSrc.openRead();
          finished = pipeStreamSink(completer, inp, process.stdin);
        } catch (e, s) {
          completer.completeError(e, s);
          finished = completer.future;
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
      if (code != 0) {
        handleFailure(project,
          mode: onFailure,
          failureMessage: cmd.relname + " exited with " + code.toString(),
          resource: cmd);
      }
      return new Future.value(null);
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
      });
    return finished.future;
  }

}
