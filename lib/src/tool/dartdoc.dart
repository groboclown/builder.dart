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


library builder.src.tool.dartdoc;


/**
 * Executes the `dartdoc` command in a separate process.
 */

import 'dart:async';

import '../../tool.dart';
import '../task/dartdoc.dart';
export '../task/dartdoc.dart' show
  DocMode;

class DartDoc extends BuildTool {
  final String cmd;

  final FailureMode onFailure;

  final DirectoryResource outDir;
  final DirectoryResource libraryRoot;
  final DirectoryResource packageRoot;
  final bool includeCode;
  final DocMode mode;
  final bool generateAppCache;
  final bool omitGenerationTime;
  final bool verbose;
  final bool includeApi;
  final bool linkApi;
  final bool showPrivate;
  final bool showInheritance;
  final Iterable<String> includeLibs;
  final Iterable<String> excludeLibs;



  // FIXME this should only explicitly call one file.

  factory DartDoc(String name,
      { String description: "", String phase: PHASE_ASSEMBLE,
      Iterable<String> depends, FailureMode onFailure,
      String cmd: null, FileResource dartFile, Iterable<FileResource> dartFiles,
      DirectoryResource outDir: null, DirectoryResource libraryRoot: null,
      DirectoryResource packageRoot: null,
      bool includeCode: true, DocMode mode: DocMode.STATIC, bool generateAppCache,
      bool omitGenerationTime: true, bool verbose: false, bool includeApi: true,
      bool linkApi: false, bool showPrivate: false, bool showInheritance: true,
      Iterable<String> includeLibs: null, Iterable<String> excludeLibs: null
      }) {

    if (depends == null) {
      depends = <String>[];
    }

    var files = <FileResource>[];
    if (dartFile != null) {
      files.add(dartFile);
    }
    if (dartFiles != null) {
      files.addAll(dartFiles);
    }

    if (outDir == null) {
      // force the outdir to be specified, to allow pipes to work right.
      outDir = new DirectoryResource.named("docs/");
    }


    var pipe = new Pipe.all(
      requiredInput: files,
      optionalInput: libraryRoot == null ? null : <Resource>[ libraryRoot ],
      output: <Resource>[ outDir ]
      );

    var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
      depends, <String>[]);
    return new DartDoc._(name, targetDef, phase, pipe, onFailure, cmd, outDir,
      libraryRoot, packageRoot, includeCode, mode, generateAppCache,
      omitGenerationTime, verbose, includeApi, linkApi, showPrivate, showInheritance,
      includeLibs, excludeLibs);
  }


  DartDoc._(String name, TargetDef targetDef, String phase, Pipe pipe,
      FailureMode onFailure,
      String cmd, DirectoryResource outDir, DirectoryResource libraryRoot,
      DirectoryResource packageRoot,
      bool includeCode, DocMode mode, bool generateAppCache,
      bool omitGenerationTime, bool verbose, bool includeApi,
      bool linkApi, bool showPrivate, bool showInheritance,
      Iterable<String> includeLibs, Iterable<String> excludeLibs) :
    this.cmd = cmd,
    this.onFailure = onFailure,
    this.outDir = outDir,
    this.libraryRoot = libraryRoot,
    this.packageRoot = packageRoot,
    this.omitGenerationTime = omitGenerationTime,
    this.includeCode = includeCode,
    this.mode = mode,
    this.generateAppCache = generateAppCache,
    this.verbose = verbose,
    this.includeApi = includeApi,
    this.linkApi = linkApi,
    this.showPrivate = showPrivate,
    this.showInheritance = showInheritance,
    this.includeLibs = includeLibs,
    this.excludeLibs = excludeLibs,
    super(name, targetDef, phase, pipe);


  @override
  Future start(Project project) {
    var inp = new List<FileResource>.from(getChangedInputs());

    if (inp.isEmpty) {
      project.logger.info("nothing to do");
      return null;
    }

    var hadErrors = false;

    StreamController<LogMessage> messages = new StreamController<LogMessage>();
    messages.stream.listen((LogMessage msg) {
      if (msg.level.startsWith("err")) {
        hadErrors = true;
      }
    });

    // Chain the calls, rather than running in parallel.
    Future ret = dartDoc(project.logger, messages,
        activeTarget: project.activeTarget,
        cmd: cmd, dartFiles: inp, outDir: outDir,
        packageRoot: packageRoot, includeCode: includeCode, mode: mode,
        generateAppCache: generateAppCache,
        omitGenerationTime: omitGenerationTime, verbose: verbose,
        includeApi: includeApi, linkApi: linkApi, showPrivate: showPrivate,
        showInheritance: showInheritance, includeLibs: includeLibs,
        excludeLibs: excludeLibs)
      .then((code) {
        if (code != 0) {
          hadErrors = true;
        }
      })
      .catchError((e, s) {
        project.logger.exception(e, s);
        hadErrors = true;
      })
      .whenComplete(() {
        messages.close();
        if (hadErrors) {
          handleFailure(project,
          mode: onFailure,
          failureMessage: "one or more files had errors");
        }
    });
    return ret;
  }
}

