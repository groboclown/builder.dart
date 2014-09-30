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


library builder.src.task.docgen;


import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../dart_path.dart';

import '../../task.dart';
import '../os.dart';




/*
 * OLD INVALID OPTIONS:
 *  --no-code
 *  --mode
 *  --generate-app-cache (similar to --compile)
 *  --omit-generation-time
 *  --verbose
 *  --include-api
 *  --link-api
 *  --show-private (now --include-private)
 *  --inherit-from-object
 */


/**
 * Spawns the dartDoc command immediately.
 *
 * The [packageRoot] is the package directory.  If [outDir] is null, the output
 * will be sent to "./docs/". The returned [Future]
 * executes when the process completes.
 */
Future docGen(Logger logger, StreamController<LogMessage> messages,
    { String cmd: null, Iterable<FileResource> dartFiles,
    DirectoryResource outDir: null, DirectoryResource packageRoot: null,
    bool compile: true, bool serve: false, bool noDocs: false,
    FileResource introduction: null, bool includeDependentPackages: true,
    bool includeSdk: true, DirectoryResource sdkDir: null,
    String startPage: null,
    bool indentJson: false,  bool includePrivate: false,
    Iterable<String> excludeLibs: null, TargetMethod activeTarget: null }) {

  if (dartFiles == null || dartFiles.isEmpty) {
    logger.info("nothing to do");
    return null;
  }

  if (cmd == null) {
    cmd = DOCGEN_NAME;
  }
  Resource exec = resolveExecutable(cmd, DART_PATH);
  if (exec == null) {
    throw new BuildExecutionException(activeTarget,
    "could not find " + cmd);
  }

  var args = <String>[];

  // --parse-sdk

  if (includeSdk) {
      args.add('--include-sdk');
  } else {
      args.add('--no-include-sdk');
  }

  if (includeDependentPackages) {
      args.add('--include-dependent-packages');
  } else {
      args.add('--no-include-dependent-packages');
  }

  if (indentJson) {
      args.add('--indent-json');
  } else {
      args.add('--no-indent-json');
  }

  if (includePrivate) {
    args.add('--include-private');
  }
  if (compile) {
    args.add('--compile');
  }
  if (serve) {
    args.add('--serve');
  }
  if (noDocs) {
    args.add('--no-docs');
  }

  if (introduction != null) {
      args
        ..add('--introduction')
        ..add(introduction.absolute);
  }

  if (startPage != null) {
      args
        ..add('--start-page')
        ..add(startPage);
  }

  // FIXME use the DART_HOME to define this
  if (sdkDir != null) {
      args
        ..add('--sdk')
        ..add(sdkDir.absolute);
  }

  if (excludeLibs != null) {
    for (String lib in excludeLibs) {
      args
        ..add('--exclude-lib')
        ..add(lib);
    }
  }

  if (outDir != null) {
    args
      ..add('--out')
      ..add(outDir.relname);
  }

  // looks like this is required
  if (packageRoot == null) {
    packageRoot = new DirectoryResource.named('packages');
  }
  args
    ..add('--package-root')
    ..add(packageRoot.relname);

  for (var f in dartFiles) {
    args.add(f.relname);
  }

  logger.debug("Running [" + exec.relname + "] with arguments " +
  args.toString());

  return Process.start(exec.relname, args).then((process) {
    // TODO add stdout and stderr into a single stream
    process.stderr.transform(new Utf8Decoder(allowMalformed: true))
      .transform(new LineSplitter()).listen((String line) {
        // TODO process the output data.
        logger.warn(line);
      });
    process.stdout.transform(new Utf8Decoder(allowMalformed: true))
      .transform(new LineSplitter()).listen((String data) {
        // TODO process the output data.
        logger.info(data);
      });
    return process.exitCode;
  }).then((code) {
    logger.fileInfo(
        file: dartFiles.first,
        message: "Completed processing " + dartFiles.toString());
    return messages.close().then((_) => code);
  });
}

