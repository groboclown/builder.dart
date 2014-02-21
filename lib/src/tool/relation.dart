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


library builder.src.tool.relation;

import 'dart:async';

import '../translatepath.dart';
import '../../tool.dart';

/**
 * Creates a relationship between files to have an implication of file
 * changes.  One example is a unit test has a dependency on a source file,
 * so if the source file changes, it should trigger a unit test change for that
 * source file.
 */
class Relationship extends BuildTool {
  factory Relationship(String name,
      { String description: "", String phase: PHASE_BUILD,
      TranslatePath translator: null,
      ResourceListable src: null, ResourceListable dest: null,
      List<PathTranslator> translators: null }) {

    var res = <PathTranslator>[];

    if (translator != null) {
      assert(src != null);
      assert(dest != null);
      res.add(new PathTranslator(src, dest, translator));
    }

    if (translators != null) {
      res.addAll(translators);
    }

    Map<Resource, List<Resource>> mapping = <Resource, List <Resource>>{};
    for (PathTranslator t in res) {
      if (! mapping.containsKey(t.srcLocation)) {
        mapping[t.srcLocation] = <Resource>[];
      }
      mapping[t.srcLocation].add(
          new TranslateResourceListable(t.srcLocation, t.destLocation,
              t.translator));
    }

    // Don't use Pipe.direct, because that creates a required relationship.
    // We want an optional relationship instead, as that puts the stand-alone
    // direct pipe sources into the optional inputs.
    Pipe pipe = new Pipe.all(directPipe: mapping,
      optionalInput: mapping.keys);

    var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
        <String>[], <String>[]);

    return new Relationship._(name, targetDef, phase, pipe);
  }



  Relationship._(String name, TargetDef targetDef, String phase, Pipe pipe) :
    super(name, targetDef, phase, pipe);


  @override
  Future start(Project project) {
    return null;
  }
}


