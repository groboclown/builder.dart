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



class GlobResource extends ResourceListable<Resource> {
  final String _name;

  final Resource srcLocation;
  final ResourceListable destLocation;
  final List<String> srcGroups;
  final List<String> destGroups;

  factory GlobResource(String srcLocation, String destLocation,
      String srcGlob, String destGlob) {


    return new GlobResource._(destGlob, srcLocation, destLocation,
      _mkGlobGroups(srcGlob), _mkGlobGroups(destGlob));
  }


  GlobResource._(this._name, this.srcLocation, this.destLocation,
      this.srcGroups, this.destGroups)


  @override
  String get name => srcLocation.name;

  @override
  String get relname => _name;

  @override
  String get absolute => destLocation.absolute;

  @override
  bool get readable => false;

  @override
  bool get writable => false;

  @override
  bool get exists => destLocation.exists;

  @override
  ResourceListable get parent => destLocation;

  @override
  path.Context get context => destLocation.context;


  // Don't support delete for now


  @override
  bool contains(Resource other) {
    // FIXME
    return false;
  }

  @override
  List<Resource> list() {
    // FIXME
  }


  @override
  Resource child(String name) {
    // TODO should this only return children that match?  I don't think so.
    return parent.child(name);
  }


  List<String> _mkGlobGroups(String glob) {
    var ret = <String>[];


    var splits;
    if (glob.startsWith("**/")) {
      splits = [ "**", glob.substring(2)];
    } else {
      splits = [ glob ];
    }

    while (splits.isNotEmpty) {
      var part = splits.removeLast();
      if (part.endsWith("/**")) {
        splits.add(part.substring(0, part.length - 2));
        splits.add("**");
      } else {
        var pos = part.indexOf("/**/");
        if (pos >= 0) {
          splits.add(part.substring(0, pos + 1));
          splits.add("**");
          splits.add(part.substring(pos + 3));
        } else {

        }

      }
    }

    return ret;
  }
}
