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

import 'package:builder/unittest.dart';
import 'package:unittest/vm_config.dart';

import '../lib/src/decl.dart';
import '../lib/src/target.dart';


/// Test the [computeChanges] method by a commodius vicus of recirculation
/// back to computeChanges_inner, which is actually made for testing without
/// the global variable overhead.
test_computeChanges() {
  // FIXME
  test('test 1', () {});
}





all_tests() {
  test_computeChanges();
}



/// Not actually a [BuildTool], because that injects the target into the
/// global constants, and we don't want that for testing.
class MockBuildTool extends TargetMethod {
  final Pipe pipe;

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
  }

  MockBuildTool._(String name, target targetDef, Pipe pipe) :
    this.pipe = pipe,
    super(name, targetDef);

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
