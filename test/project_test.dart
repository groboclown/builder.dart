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

library project_test;

import 'dart:async';

import 'package:builder/unittest.dart';
import 'package:unittest/vm_config.dart';

import '../lib/src/argparser.dart';
import '../lib/src/project.dart';
import '../lib/src/targetmethod.dart';


test_TopologicalSort() {
  group("topo sort", () {
    test("weak link", () {
      MockTarget.callOrder.clear();
      var targets = [ new MockTarget("1", [ "1a" ], []),
        new MockTarget("1a", [], []),
        new MockTarget("2", [], []),
        new MockTarget("x1", [], [ "x2", "1" ]),
        new MockTarget("x2", [], [ "2" ])
      ];
      var args = [ "1", "x2", "2" ];
      runProject(targets, args).then((_) =>
        expect(MockTarget.callOrder,
          equals([ "1a", "1", "2", "x2" ])));
    });
  });
}


Future<int> runProject(List<TargetMethod> targets, List<String> args) {
  BuildArgs ba = new BuildArgs.fromCmd(args, targets);
  Project p = new Project.parse(ba);
  return p.buildTargets(ba.calledTargets);
}


class MockTarget extends TargetMethod {
  static List<String> callOrder = <String>[];

  MockTarget(String name, List<String> strong, List<String> weak) :
    super(name, new TargetDef(name, strong, weak, false));

  Future start(Project project) {
    callOrder.add(name);
    print("Call order ${callOrder}");
    return null;
  }
}


all_tests() {
  test_TopologicalSort();
}



main(List<String> args, [ replyTo ]) {
  selectConfiguration(replyTo, useVMConfiguration);
  all_tests();
  if (!args.isEmpty) {
    filterTests(args[0]);
  }
}
