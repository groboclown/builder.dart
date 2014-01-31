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
 * Adds OS-specific knowledge to the standard Dart objects ([Process] and
 * [Platform])
 */

library builder.exec;

import 'dart:io';
import 'resource.dart';
import 'src/exceptions.dart';

final Map<String, List<String>> EXEC_EXT_LIST = <String, List<String>>{
  "linux": <String>[ "", ".sh", ".py", ".pl" ],
  "macos": <String>[ "", ".sh", ".py", ".pl" ],
  "windows": <String>[ ".exe", ".com", ".bat", ".cmd", ".py", ".pl" ],
  "android": null
};



/**
 *
 */
Resource resolveExecutable(String name, [ List<String> additionalPath ]) {
  var EXEC_EXT = EXEC_EXT_LIST[Platform.operatingSystem];
  if (EXEC_EXT == null) {
    throw new BuildException("executing not supported on your OS (" +
      Platform.operatingSystem + ")");
  }
  var path = parseDirectoryPath(Platform.environment['PATH']);
  if (additionalPath != null) {
    for (var p in additionalPath) {
      var r = filenameToResource(p);
      if (r != null && r.exists && r.isDirectory) {
        path.add(r);
      }
    }
  }
  
  for (var ext in EXEC_EXT) {
    var execFile = filenameToResource(name + ext);
    if (execFile != null && execFile.exists && ! execFile.isDirectory) {
      return execFile;
    }
    if (! name.contains('/') && ! name.contains('\\')) {
      for (var p in path) {
        var execFile = filenameToResource(p.fullName + '/' + name + ext);
        if (execFile.exists && ! execFile.isDirectory) {
          return execFile;
        }
      }
    }
  }
  
  return null;
}


/**
 * Splits a path definition into separate [DirectoryResource] objects,
 * using ':', ';', or [Platform.pathSeparator].  The returned items
 * may not exist.
 */
List<ResourceListable> parseDirectoryPath(String path,
    [ bool isDosLike = null, String pathSeparator ]) {
  var ret = <ResourceListable>[];
  if (path == null) {
    return ret;
  }
  if (isDosLike == null) {
    isDosLike = Platform.isWindows;
  }
  for (String p in splitPath(path, isDosLike, pathSeparator)) {
    var f = filenameToResource(p);
    if (f != null && f is ResourceListable) {
      ret.add(f);
    }
  }
  return ret;
}


/**
 * Splits a path definition into separate [DirectoryResource] objects,
 * using ':', ';', or [Platform.pathSeparator].
 *
 * This is based off of Ant's `PathTokenizer` class.
 */
List<String> splitPath(String path,
    [ bool isDosLike = null, String pathSeparatorMatcher ]) {
  if (isDosLike == null) {
    isDosLike = Platform.isWindows;
  }
  if (pathSeparatorMatcher == null) {
    pathSeparatorMatcher = r"[\;\:\" + Platform.pathSeparator + "]";
  }
  var ret = <String>[];
  if (path == null) {
    return ret;
  }
  var buff = new StringBuffer(path);
  while (! buff.isEmpty) {
    var el = _nextPathElement(buff, isDosLike, pathSeparatorMatcher);
    if (el != null && el.isNotEmpty) {
      ret.add(el);
    }
  }
  return ret;
}

final RegExp WINDOWS_PATH_PREFIX = new RegExp(r"^[a-zA-Z]\:[\\\/]");

String _nextPathElement(StringBuffer path, bool isDosLike, String pathSep) {
  if (path.isEmpty) {
    return null;
  }
  var p = path.toString().trim();
  var ret = "";
  if (isDosLike && WINDOWS_PATH_PREFIX.hasMatch(p)) {
    ret = p.substring(0, 3);
    p = p.substring(3);
    path.clear();
    path.write(p);
  }
  var m = new RegExp("^(.*?)" + pathSep + r"(.*)$").firstMatch(p);
  if (m != null) {
    ret += m.group(1);
    path.clear();
    path.write(m.group(2));
  } else {
    ret += p;
    path.clear();
  }
  if (ret.isEmpty) {
    return null;
  }
  return ret.trim();
}




