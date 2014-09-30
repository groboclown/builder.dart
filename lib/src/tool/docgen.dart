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


library builder.src.tool.docgen;


/**
 * Executes the `dartdoc` command in a separate process.
 */

import 'dart:async';

import '../../tool.dart';
import '../task/docgen.dart';

/**
 * Backwards compatibility.  This is the obsolete DartDoc tool.
 */
class DartDoc extends DocGen {
    factory DartDoc(String name,
          { String description: "", String phase: PHASE_ASSEMBLE,
          Iterable<String> depends, FailureMode onFailure,
          String cmd: null, FileResource dartFile, Iterable<FileResource> dartFiles,
          DirectoryResource outDir: null, DirectoryResource libraryRoot: null,
          DirectoryResource packageRoot: null,
          bool includeCode: true, var mode: null, bool generateAppCache,
          bool omitGenerationTime: true, bool verbose: false, bool includeApi: true,
          bool linkApi: false, bool showPrivate: false, bool showInheritance: true,
          Iterable<String> includeLibs: null, Iterable<String> excludeLibs: null
          }) {

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
        optionalInput: null,
        output: <Resource>[ outDir ]
        );
      var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
        depends, <String>[]);

      return new DartDoc._(name, targetDef, phase, pipe, onFailure, outDir,
        packageRoot, showPrivate, showInheritance, excludeLibs);
    }

    DartDoc._(String name, TargetDef targetDef, String phase, Pipe pipe,
            FailureMode onFailure,
        DirectoryResource outDir, DirectoryResource packageRoot,
        bool showPrivate, bool showInheritance, Iterable<String> excludeLibs) :
        super._(name, targetDef, phase, pipe, onFailure,
          null, // cmd is intentionally ignored - it's incompatible
          outDir, packageRoot,
          null, // introduction
          null, // sdkDir
          false, // compile
          false, // serve
          false, // noDocs
          showPrivate, // includePrivate,
          showInheritance, // includeDependentPackages
          true, // includeSdk
          false, // indentJson
          null, // startPage
          excludeLibs);
}

class DocGen extends BuildTool {
  final String cmd;

  final FailureMode onFailure;

  final DirectoryResource outDir;
  final DirectoryResource packageRoot;
  final FileResource introduction;
  final DirectoryResource sdkDir;
  final bool compile;
  final bool serve;
  final bool noDocs;
  final bool includePrivate;
  final bool includeDependentPackages;
  final bool includeSdk;
  final bool indentJson;
  final String startPage;
  final Iterable<String> excludeLibs;


  // FIXME this should only explicitly call one file.

  factory DocGen(String name,
      { String description: "", String phase: PHASE_ASSEMBLE,
      Iterable<String> depends, FailureMode onFailure,

      String cmd: null, FileResource dartFile, Iterable<FileResource> dartFiles,
      DirectoryResource outDir: null, DirectoryResource packageRoot: null,
      FileResource introduction: null, bool compile: false, bool serve: false,
      bool noDocs: false, bool includePrivate: false,
      bool includeDependentPackages: true, bool includeSdk: true,
      bool indentJson: false, DirectoryResource sdkDir, String startPage: null,
      Iterable<String> excludeLibs: null
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
      optionalInput: sdkDir == null ? null : <Resource>[ sdkDir ],
      output: <Resource>[ outDir ]
      );

    var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
      depends, <String>[]);
    return new DocGen._(name, targetDef, phase, pipe, onFailure, cmd, outDir,
      packageRoot, introduction, sdkDir, compile, serve, noDocs, includePrivate,
      includeDependentPackages, includeSdk, indentJson, startPage, excludeLibs);
  }


  DocGen._(String name, TargetDef targetDef, String phase, Pipe pipe,
      this.onFailure,
      this.cmd, this.outDir, this.packageRoot, this.introduction,
      this.sdkDir, this.compile, this.serve, this.noDocs, this.includePrivate,
      this.includeDependentPackages, this.includeSdk, this.indentJson,
      this.startPage, this.excludeLibs) :
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
    Future ret = docGen(project.logger, messages,
        activeTarget: project.activeTarget,
        cmd: cmd, dartFiles: inp, outDir: outDir,
        packageRoot: packageRoot,
        compile: compile, serve: serve, noDocs: noDocs,
        introduction: introduction,
        includeDependentPackages: includeDependentPackages,
        includeSdk: includeSdk, sdkDir: sdkDir,
        startPage: startPage, indentJson: indentJson,
        includePrivate: includePrivate,
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

