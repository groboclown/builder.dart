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


library builder.src.tool.dart;

import 'dart:io';

import 'package:path/path.dart' as path;
import '../decl.dart';
import '../resource.dart';
import '../project.dart';

/**
 * Creates a relationship between files to have an implication of file
 * changes.  One example is a unit test has a dependency on a source file,
 * so if the source file changes, it should trigger a unit test change for that
 * source file.
 */
class Relationship extends BuildTool {
  static int _relationshipCount = 0;

  factory Relationship(String name,
      { String description: "", Map<Resource, Resource> mapper}) {

    assert(mapper != null);




  }



  Relationship._(String name, target targetDef, Pipe pipe) :
    super(name, targetDef, pipe);

}


/**
 * Description for translating a path from one location to another.  Used by
 * the [TranslatedResource].  Returns `null` if [srcPath] does not match
 * the translation, or the translated path.
 */
typedef String TranslatePath(String srcPath);

/**
 * Uses "*" and "**" as glob placements in the source.  The number of glob
 * patterns in [src] must match up with the glob patterns in [dest].
 *
 * "**" can only be used by itself in a directory specification, such as
 * "a/ ** /b"; the form "a**b/c" is not allowed.  The "*" will match within a
 * single directory.
 *
 * For now, the "*" can only be used once in a directory.
 */
TranslatePath globTranslator(String src, String dest,
    [ path.Context context = null, bool caseSensitive = null ]) {
  assert(_count(src, "*") == _count(dest, "*"));
  if (context == null) {
    context = new path.Context(style: path.style);
  }
  if (caseSensitive == null) {
    caseSensitive = Platform.isWindows;
  }
  var srcParts = context.split(src);
  assert(srcParts.isNotEmpty);
  var destParts = context.split(dest);
  assert(destParts.isNotEmpty);

  String translatePathStars(String src, String dest, String actual) {
    int starCount = _count(src, "*");
    var srcRegExp = "";
    for (int i = 0; i < src.length; i++) {
      if ((src.codeUnitAt(i) >= 'a'.codeUnitAt(0) && src.codeUnitAt(i) <= 'z'.codeUnitAt(0)) ||
          (src.codeUnitAt(i) >= 'A'.codeUnitAt(0) && src.codeUnitAt(i) <= 'Z'.codeUnitAt(0)) ||
          (src.codeUnitAt(i) >= '0'.codeUnitAt(0) && src.codeUnitAt(i) <= '9'.codeUnitAt(0))) {
        srcRegExp += src[i];
      } else if (src[i] == "*") {
        srcRegExp += "(.*?)";
        ++starCount;
      } else {
        srcRegExp += "\\" + src[i];
      }
    }

    // FIXME include case sensitivity flag
    var re = new RegExp("^" + srcRegExp + "\$", caseSensitive: caseSensitive);
    var m = re.firstMatch(actual);
    if (m == null) {
      return null;
    }

    String ret = "";
    int group = 1;
    for (int i = 0; i < dest.length; ++i) {
      if (dest[i] == "*") {
        ret += m[group++];
      } else {
        ret += dest[i];
      }
    }

    return ret;
  }

  TranslatePath ret = (String p) {
    var pParts = context.split(p);
    var out = <String>[];

    var srcPos = 0;
    var destPos = 0;
    var pPos = 0;

    while (true) {
      print("srcParts[$srcPos]=[${srcParts[srcPos]}]");
      print("destParts[$destPos]=[${destParts[destPos]}]");
      print("pParts[$pPos]=[${pParts[pPos]}]");
      if (srcParts[srcPos] == "**") {
        // put in place of the "**" the destination path up to its "**".
        for (; destPos < destParts.length &&
            destParts[destPos] != "**"; ++destPos) {
          assert(destParts[destPos].indexOf("*") < 0);
          out.add(destParts[destPos]);
        }

        // destPos && srcPos both point to **, or destPos is at the end of
        // the string.

        if (srcPos >= srcParts.length - 1) {
          // ending with double star
          assert(destPos >= destPos.length - 1);
          for (; pPos < pParts.length; ++pPos) {
            out.add(pParts[pPos]);
          }
          break;
        }

        assert(srcParts[srcPos] != "**");

        // swallow up pPos paths until the first match with dest
        // FIXME this should use translatePathStars above
        for (; pPos < pParts.length &&
            pParts[pPos] != srcParts[srcPos + 1]; ++pPos) {
          // do nothing - we're incrementing and testing in the for statement.
        }
        if (pPos >= pParts.length) {
          // not a match - too much consumed
          return null;
        }


        // FIXME what next?

        assert(destPos < destParts.length);
      } else if (_count(srcParts[srcPos], "*") > 0) {
        assert(_count(srcParts[srcPos], "**") <= 0);
        for (; destPos < destParts.length && _count(destParts[destPos], "*") <= 0; ++destPos) {
          // the check and inc is done in the for loop.
          out.add(destParts[destPos]);
        }
        assert(_count(destParts[destPos], "**") <= 0);
        var tr = translatePathStars(srcParts[srcPos], destParts[destPos], pParts[pPos]);
        if (tr == null) {
          // not a match
          return null;
        }
        ++srcPos;
        ++destPos;
        ++pPos;
      } else if (_count(destParts[destPos], "*") > 0) {
        for (; srcPos < srcParts.length; ++srcPos) {
          if (_count(srcParts[srcPos], "*") > 0) {
            break;
          }
          if (srcParts[srcPos] != pParts[pPos]) {
            // not a match
            return null;
          }
          ++pPos;
        }
        assert(_count(srcParts[srcPos], "**") <= 0);
        var tr = translatePathStars(srcParts[srcPos], destParts[destPos],
        pParts[pPos]);
        if (tr == null) {
          // not a match
          return null;
        }
        ++srcPos;
        ++destPos;
        ++pPos;
      } else {
        if (pParts[pPos] != srcParts[srcPos]) {
          // not a match
          return null;
        }
        ++srcPos;
      }

      if (srcPos >= srcParts.length) {
        // end of the search.
        for (; destPos < destParts.length; ++destPos) {
          out.add(destParts[destPos]);
        }
        return path.joinAll(out);
      }
    }
  };
  return ret;
}



int _count(String str, String char) {
  int count = 0;
  int pos = str.indexOf(char);
  while (pos < str.length && pos >= 0) {
    count++;
    pos = str.indexOf(char, pos + char.length);
  }
  return count;
}
