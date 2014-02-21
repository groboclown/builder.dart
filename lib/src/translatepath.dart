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


library builder.src.tool.translatepath;

import 'dart:io';

import 'package:path/path.dart' as path;
import '../tool.dart';



/**
 * Description for translating a path from one location to another.  Used by
 * the [TranslatedResource].  Returns `null` if [srcPath] does not match
 * the translation, or the translated path.
 */
typedef String TranslatePath(String srcPath);


/**
 * Contains the translation from the [source] to the [target].  Neither can
 * be `null`.
 */
class PathTranslated {
  final Resource source;
  final Resource target;

  PathTranslated(this.source, this.target) {
    assert(source != null);
    assert(target != null);
  }
}


class PathTranslator {
  final ResourceListable srcLocation;
  final ResourceListable destLocation;
  final TranslatePath translator;

  const PathTranslator(this.srcLocation, this.destLocation, this.translator);

  Iterable<PathTranslated> list() {
    return srcLocation.list().map((s) {
      var rels = srcLocation.relativeChildName(s);
      var trans = translator(rels);
      if (trans == null) {
        return null;
      }
      return new PathTranslated(s, destLocation.child(trans));
    }).where((p) => p != null);
  }
}



/**
 * A [ResourceListable] that has its contents as the translated source
 * resources.
 */
class TranslateResourceListable<T extends Resource> extends ResourceListable {
  final ResourceListable srcLocation;
  final ResourceListable<T> destLocation;
  final TranslatePath translator;

  TranslateResourceListable(this.srcLocation, this.destLocation,
      this.translator);

  @override
  String get name => destLocation.name;

  @override
  String get relname => destLocation.relname;

  @override
  String get absolute => destLocation.absolute;

  @override
  bool get readable => destLocation.readable;

  @override
  bool get writable => destLocation.writable;

  @override
  bool get exists => destLocation.exists;

  @override
  ResourceListable get parent => destLocation.parent;

  @override
  path.Context get context => destLocation.context;

  @override
  bool delete(bool recursive) => destLocation.delete(recursive);

  // here, we just check if this "other" is contained in the destination.
  // it doesn't match against the source, because the source is not contained
  // in this!
  @override
  bool contains(Resource other) => destLocation.contains(other);

  @override
  String relativeChildName(Resource child) => destLocation.relativeChildName(child);

  @override
  List<T> list() {
    return srcLocation.list().map((s) {
      var rels = srcLocation.relativeChildName(s);
      var trans = translator(rels);
      if (trans == null) {
        return null;
      }
      return destLocation.child(trans);
    }).where((s) => s != null);
  }

  @override
  T child(String name) {
    var trans = translator(name);
    if (trans == null) {
      return null;
    }
    return destLocation.child(trans);
  }
}







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
  assert(_count(src, "*") == _count(dest, "*") + _count(dest, "%"));
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
    int starCount = 0;
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
      } else if (dest[i] == "%") {
        // ignore it
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
      // First - move all the destination parts, up to anything with a matcher,
      // into the output list.
      for (; destPos < destParts.length &&
          (destParts[destPos].indexOf("*") < 0 &&
            destParts[destPos].indexOf("%") < 0);
          ++destPos) {
        //print("consume dest [${destParts[destPos]}");
        out.add(destParts[destPos]);
      }

      // Next, move through the source until it reaches a matcher, comparing it
      // to the pParts list.  If it's a mismatch, then the pParts is not valid
      // for this translation.
      for (; srcPos < srcParts.length && pPos < pParts.length &&
          (srcParts[srcPos].indexOf("*") < 0); ++srcPos, ++pPos) {
        var s = srcParts[srcPos];
        var p = pParts[pPos];
        if (! caseSensitive) {
          s = s.toLowerCase();
          p = p.toLowerCase();
        }
        if (s != p) {
          //print("incorrect match: src[$srcPos] ($s) != p[$pPos] ($p)");
          return null;
        }
        //print("match src [${srcParts[srcPos]}] to p [${pParts[pPos]}]");
      }

      if (destPos >= destParts.length) {
        if (srcPos >= srcParts.length) {
          // correct end of the matching
          //print("end of matching");
          return path.joinAll(out);
        }
        //print("dest path length does not match up with the source path length for p");
        return null;
      }
      if (srcPos >= srcParts.length) {
        //print("src path length does not match up with the dest path length for p");
        return null;
      }
      if (pPos >= pParts.length) {
        //print("parts path length is longer than source path length");
        return null;
      }

      // Now we're at a matcher
      if (srcParts[srcPos] == "**") {
        // matcher of an arbitrary number of directories.
        if (destParts[destPos] != "**" && destParts[destPos] != "%%") {
          //print("multi-directory matcher does not match up for dest and src for p");
          return null;
        }

        if (srcPos == srcParts.length - 1) {
          // special case - last is **
          // last part cannot be "%%"
          assert(destParts[destPos] == "**");
          assert(destPos == destParts.length - 1);
          for (; pPos < pParts.length; ++pPos) {
            //print("move p [${pParts[pPos]}] for **");
            out.add(pParts[pPos]);
          }
          return path.joinAll(out);
        }

        // swallow up pParts until it matches the next srcPos.
        ++srcPos;
        assert(srcParts[srcPos] != "**");
        var useP = (destParts[destPos] == "**");
        ++destPos;
        for (; pPos < pParts.length; ++pPos) {
          var translate = translatePathStars(srcParts[srcPos],
            destParts[destPos], pParts[pPos]);
          //print("match for [${srcParts[srcPos]}], [${destParts[destPos]}], to [${pParts[pPos]}], as [${translate}]");
          if (translate != null) {
            // match on the part after the **
            //print("match on part ${pParts[pPos]} after **");
            out.add(translate);

            ++pPos;
            ++srcPos;
            ++destPos;

            if (srcPos >= srcParts.length) {
              if (destPos >= destParts.length) {
                if (pPos >= pParts.length) {
                  return path.joinAll(out);
                }
                //print("pParts remainder after end of matcher");
                return null;
              }
              //print("destParts remainder after end of src matcher");
              return null;
            }

            break;
          }
          if (useP) {
            //print("move p [${pParts[pPos]}] for **");
            out.add(pParts[pPos]);
          }
        }
        if (pPos >= pParts.length) {
          //print("mismatch of p against src for multi-directory matcher");
          return null;
        }
      } else {
        // star matcher.
        if (destParts[destPos] == "**" || destParts[destPos] == "%%") {
          //print("single directory matcher does not match up for dest and src for p");
          return null;
        }

        var translate = translatePathStars(srcParts[srcPos],
          destParts[destPos], pParts[pPos]);
        if (translate == null) {
          //print("single directory matcher did not match on ${pParts[pPos]}");
          return null;
        }
        //print("match star for [${srcParts[srcPos]}], [${destParts[destPos]}], to [${pParts[pPos]}], as [${translate}]");
        out.add(translate);

        srcPos++;
        destPos++;
        pPos++;
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
