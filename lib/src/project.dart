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



library builder.src.project;

import 'logger.dart';
import 'argparser.dart';
import 'target.dart';

class Project {
  final Logger logger;
  final List<TargetMethod> _targets;
  final List<TargetMethod> _invokedTargets = [];
  final Map<String, String> properties = {};

  Project.parse(BuildArgs args) :
      logger = args.logger,
      _targets = args.allTargets;


  List<TargetMethod> get targets => new List<TargetMethod>.from(_targets);

  List<String> get targetNames => new List<String>.from(_targets.map((t) => t.name));

  TargetMethod findTarget(String name) {
    for (TargetMethod tm in _targets) {
      if (tm.name == name) {
        return tm;
      }
    }
    return null;
  }


  void build(String target) {
    buildTarget(findTarget(target));
  }


  /**
   * Run the full build for this specific [TargetMethod].  It will not repeat
   * any target that has already been run in this project.
   */
  void buildTarget(TargetMethod m) {
    if (m == null) {
      throw new Exception("null target");
    }
    if (_invokedTargets.contains(m)) {
      // do nothing
      return;
    }

    // run the dependencies and the target
    for (TargetMethod tm in _dependencyList(m)) {
      tm.call(this);
    }
  }


  /**
   * Return the list of targets to execute for this target, which means
   * constructing an ordered dependency chain (including `m` at the very
   * end), excluding all the already-executed dependencies.
   */
  List<TargetMethod> _dependencyList(TargetMethod m) {
    // FIXME

  }
}
