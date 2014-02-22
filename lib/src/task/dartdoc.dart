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


library builder.src.task.dartdoc;


import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../dart_path.dart';

import '../../task.dart';
import '../os.dart';



class DocMode {
  static const LIVE_NAV = const DocMode._("live-nav");
  static const STATIC = const DocMode._("static");

  final String arg;
  const DocMode._(this.arg);
}


/**
 * Spawns the dartDoc command immediately.
 *
 * The [packageRoot] is the package directory.  If [outDir] is null, the output
 * will be sent to "./docs/". The returned [Future]
 * executes when the process completes.
 */
Future dartDoc(Logger logger, StreamController<LogMessage> messages,
    { String cmd: null, Iterable<FileResource> dartFiles,
    DirectoryResource outDir: null, DirectoryResource libraryRoot: null,
    DirectoryResource packageRoot: null,
    bool includeCode: true, DocMode mode: DocMode.STATIC, bool generateAppCache,
    bool omitGenerationTime: true, bool verbose: false, bool includeApi: true,
    bool linkApi: false, bool showPrivate: false, bool showInheritance: true,
    Iterable<String> includeLibs: null, Iterable<String> excludeLibs: null,
    TargetMethod activeTarget: null }) {

  if (dartFiles == null || dartFiles.isEmpty) {
    logger.info("nothing to do");
    return null;
  }

  if (cmd == null) {
    cmd = DART_DOC_NAME;
  }
  Resource exec = resolveExecutable(cmd, DART_PATH);
  if (exec == null) {
    throw new BuildExecutionException(activeTarget,
    "could not find " + cmd);
  }

  var args = <String>[];

  if (! includeCode) {
    args.add('--no-code');
  }
  if (mode != null) {
    args.add("--mode");
    args.add(mode.arg);
  }
  if (generateAppCache) {
    args.add('--generate-app-cache');
  }
  if (omitGenerationTime) {
    args.add('--omit-generation-time');
  }
  if (verbose) {
    args.add('--verbose');
  }
  if (includeApi) {
    args.add('--include-api');
  }
  if (linkApi) {
    args.add('--link-api');
  }
  if (showPrivate) {
    args.add('--show-private');
  }
  if (showInheritance) {
    args.add('--inherit-from-object');
  }
  // --enable-diagnostic-colors

  if (includeLibs != null) {
    for (String lib in includeLibs) {
      args
        ..add('--include-lib')
        ..add(lib);
    }
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
  if (libraryRoot != null) {
    args
      ..add('--library-root')
      ..add(libraryRoot.relname);
  }

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

