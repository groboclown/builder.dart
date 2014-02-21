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


library builder.src.tool.copy;

/**
 * Copies files.
 *
 * Future support will need to include a simple templating (filter) support,
 * and name mapping.
 */

import 'dart:async';
import 'dart:io';

import '../../tool.dart';



/**
 * Exactly one of ([destDir], [destFile]) must be given; [destFile] can only be
 * used if [srcFile] is specified.
 *
 * Exactly one of ([srcDir], [srcFile], [srcFiles]) must be given.
 */
class Copy extends BuildTool {
  final FailureMode onFailure;

  final bool overwrite;

  final Resource output;

  final Resource input;

  final String encoding;

  bool get isText => encoding != null;




  factory Copy.file(String name, {
      String description: "", String phase: PHASE_ASSEMBLE,
      List<String> depends: null, ResourceStreamable src: null,
      ResourceStreamable destFile: null, ResourceListable destDir: null,
      String encoding: null,
      bool overwrite: false, FailureMode onFailure: null
      }) {

    if (src != null) {
      throw new BuildSetupException("must specify src");
    }

    var out;
    if (destDir != null) {
      if (destFile != null) {
        throw new BuildSetupException(
            "must specify exactly one of (destDir, destFile)");
      }

      out = destDir.child(destFile.name);
    } else if (destFile != null) {
      out = destFile;
    } else {
      throw new BuildSetupException(
          "must specify exactly one of (destDir, destFile)");
    }


    var pipe = new Pipe.single(src, out);

    var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
      depends, <String>[]);

    return new Copy._(name, targetDef, phase, pipe, overwrite, encoding,
      onFailure, src, out);
  }


  factory Copy.dir(String name, {
      String description: "", String phase: PHASE_ASSEMBLE,
      List<String> depends: null, ResourceListable src: null,
      ResourceListable dest: null, String encoding: null,
      bool overwrite: false, FailureMode onFailure: null
      }) {

    if (src == dest) {
      throw new BuildSetupException(
          "copy does not allow the source directory and destination directory to match (${src})");
    }

    var pipe = new Pipe.single(src, dest);

    var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
      depends, <String>[]);

    return new Copy._(name, targetDef, phase, pipe, overwrite, encoding,
      onFailure, src, dest);
  }


  factory Copy.collection(String name, {
      String description: "", String phase: PHASE_ASSEMBLE,
      List<String> depends: null, ResourceCollection src: null,
      ResourceListable dest: null, String encoding: null,
      ResourceListable rootDir: null, // can be null
      bool overwrite: false, FailureMode onFailure: null
      }) {

    var pipe = new Pipe.list(src.entries(), <Resource>[ dest ]);

    var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
      depends, <String>[]);

    return new Copy._(name, targetDef, phase, pipe, overwrite, encoding,
      onFailure, rootDir, dest);

  }


  Copy._(String name, TargetDef targetDef, String phase, Pipe pipe,
      bool overwrite, String encoding, FailureMode onFailure,
      Resource input, Resource output) :
    this.overwrite = overwrite,
    this.onFailure = onFailure,
    this.encoding = encoding,
    this.input = input,
    this.output = output,
    super(name, targetDef, phase, pipe);



  @override
  Future<Project> start(Project project) {
    // FIXME use getChangedInputs()

    var hasErrors = false;

    var ret = new Future<Project>(() {
      if (hasErrors) {
        handleFailure(project,
          mode: onFailure,
          failureMessage: "failed on copy",
          resource: input);
      }
      return project;
    });
    if (input != null && input is ResourceStreamable) {
      var f = _copyFile(input, output);
      if (f != null) {
        f.catchError((e, s) {
          hasErrors = true;
        });
        ret = f.then((_) => ret);
      } else {
        hasErrors = true;
      }
    } else {
      for (var r in pipe.requiredInput) {
        if (! r.exists || ! r.readable) {
          project.logger.fileWarn(tool: "copy",
            file: r, message: "source file does not exist or is not readable");
        } else if (r is ResourceListable) {
          for (var c in r.list()) {
            var f = _copyRelFile(project, c);
            if (f != null) {
              f.catchError((e, s) {
                hasErrors = true;
              });
              ret = f.then((_) => ret);
            } else {
              hasErrors = true;
            }
          }
        } else if (r is ResourceStreamable) {
          var f = _copyRelFile(project, r);
          if (f != null) {
            f.catchError((e, s) {
              hasErrors = true;
            });
            ret = f.then((_) => ret);
          } else {
            hasErrors = true;
          }
        } else {
          project.logger.fileWarn(tool: "copy",
            file: r, message: "unknown file type " + f.dynamicType);
        }
      }
    }
    return ret;
  }


  Future _copyRelFile(Project project, ResourceStreamable source) {
    var sname = source.relname;
    if (input != null) {
      sname = (input as ResourceListable).relativeChildName(source);
      if (sname == null) {
        project.logger.fileError(tool: "copy", file: source,
          message: "cannot map from ${source} into ${input}");
        return null;
      }
    }
    return _copyFile(project, source,
      (output as ResourceListable).child(sname));
  }



  Future _copyFile(Project project, ResourceStreamable source,
      ResourceStreamable target) {
    project.logger.fileInfo(tool: "copy", file: target,
      message: "copying ${source} to ${target}");
    try {
      Completer completer = new Completer();

      // FIXME include error handling
      IOSink outp = target.openWrite(encoding: encoding);
      Stream<List<int>> inp = source.openRead();
      inp.listen((List<int> data) {
        try {
          outp.add(data);
        } catch (e, s) {
          outp.close();
          target.delete();
          project.logger.fileError(tool: "copy", file: target,
            message: "failed to copy ${source} to ${target}");
          completer.completeError(e, s);
        }
      }, onDone: () {
        outp.close();
        completer.complete();
      }, onError: (e, s) {
        outp.close();
        target.delete(false);
        project.logger.fileError(tool: "copy", file: source,
          message: "failed to copy ${source} to ${target}");
        completer.completeError(e, s);
      }, cancelOnError: true);

      return completer.future;
    } catch (e, s) {
      project.logger.fileError(tool: "copy", file: source,
        message: "problem copying from ${source} to ${target}: ${e}");
      return null;
    }
  }
}
