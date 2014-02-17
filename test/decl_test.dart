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

library decl_test;

import 'dart:async';
import 'dart:io';

import 'package:builder/unittest.dart';
import 'package:unittest/vm_config.dart';

import '../lib/src/resource.dart';
import '../lib/src/decl.dart';
import '../lib/src/target.dart';
import '../lib/src/project.dart';



/// Test the [_connectPipes] method by calling into the inner method
/// [connectPipe_internal], which was made for testing without
/// the global variable overhead.
/// In the same way, this also tests the [computeChanges] method
/// by a commodius vicus of recirculation back to
/// [computeChanges_inner].
test_computeChanges() {
  Map<Resource, List<BuildTool_inner>> pipedInput = {};
  Map<Resource, List<BuildTool_inner>> pipedOutput = {};
  var file1 = new FileResource(new File('f1'), GLOBAL_CONTEXT, "f1");
  var file2 = new FileResource(new File('f2'), GLOBAL_CONTEXT, "f2");
  var tool1 = new MockBuildTool("tool1", "tool1",
    output: [ file1 ]);
  var tool2 = new MockBuildTool("tool2", "tool2",
    requiredInput: [ file1 ], output: [ file2 ]);

  connectPipe_internal(tool1, pipedInput, pipedOutput);
  connectPipe_internal(tool2, pipedInput, pipedOutput);


  test('no changes', () {
    var changed = new Set<Resource>();
    var targets = computeChanges_inner(changed, pipedInput);
    expect(targets, isEmpty);
    expect(changed, isEmpty);
  });

  test('one dependency', () {
    var changed = new Set<Resource>();
    changed.add(file1);
    var targets = computeChanges_inner(changed, pipedInput);
    expect(targets, unorderedEquals([ tool2 ]));
    expect(changed, unorderedEquals([ file1, file2 ]));
  });
}


test_connectPipe() {
  group('Single Connection', () {
    Map<Resource, List<BuildTool_inner>> pipedInput = {};
    Map<Resource, List<BuildTool_inner>> pipedOutput = {};

    var file1 = new FileResource(new File('f'), GLOBAL_CONTEXT, "f");
    var tool1 = new MockBuildTool("tool1", "tool1",
      output: [ file1 ]);
    var tool2 = new MockBuildTool("tool2", "tool2",
      requiredInput: [ file1 ]);

    connectPipe_internal(tool1, pipedInput, pipedOutput);
    connectPipe_internal(tool2, pipedInput, pipedOutput);

    test('tool2..strongDepends', () =>
      expect(tool2.targetDef.strongDepends, unorderedEquals([ tool1.name ])));
    test('tool2..weakDepends', () =>
      expect(tool2.targetDef.weakDepends, isEmpty));
    test('tool1..strongDepends', () =>
      expect(tool1.targetDef.strongDepends, isEmpty));
    test('tool1..weakDepends', () =>
      expect(tool1.targetDef.weakDepends, isEmpty));
    test('pipedInput.keys', () =>
      expect(pipedInput.keys, unorderedEquals([ file1 ])));
    test('pipedInput[file1]', () =>
      expect(pipedInput[ file1 ], unorderedEquals([ tool2 ])));
    test('pipedOutput.keys', () =>
      expect(pipedOutput.keys, unorderedEquals([ file1 ])));
    test('pipedOutput[file1]', () =>
      expect(pipedOutput[ file1 ], unorderedEquals([ tool1 ])));
  });
}




all_tests() {
  test_computeChanges();
  test_connectPipe();
}



/// Not actually a [BuildTool], because that injects the target into the
/// global constants, and we don't want that for testing.  It should be a
/// [BuildTool] in regards to type safety, but this adds the only additional
/// thing needed by the test methods that BuildTool has and TargetMethod
/// doesn't ([pipe] getter).
class MockBuildTool extends BuildTool_inner {
  factory MockBuildTool(String name, String description,
      { Iterable<String> dependencies, Iterable<String> weakDependencies,
      Iterable<Resource> requiredInput, Iterable<Resource> optionalInput,
      Iterable<Resource> output, Map<Resource, Iterable<Resource>> directPipe}) {
    var pipe = new Pipe.all(requiredInput: requiredInput,
        optionalInput: optionalInput, output: output, directPipe: directPipe);
    if (dependencies == null) {
      dependencies = <String>[];
    }
    if (weakDependencies == null) {
      weakDependencies = <String>[];
    }
    var targetDef = new target.internal(description,
      dependencies, weakDependencies, false);
    return new MockBuildTool._(name, targetDef, pipe);
  }

  MockBuildTool._(String name, target targetDef, Pipe pipe) :
    super(name, targetDef, pipe);

  @override
  Future<Project> start(Project project) {
    // do nothing
    return new Future<Project>(() => project);
  }
}






main(List<String> args, [ replyTo ]) {
  selectConfiguration(replyTo, useVMConfiguration);
  all_tests();
  if (!args.isEmpty) {
    filterTests(args[0]);
  }
}
