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


library builder.transformer.unittest;

/**
 * Transformer for use with the `pub` command, to allow running unit tests
 * as part of the "build" process.
 *
 * Run this by setting up your pubspec.yaml file like:
 *
 *     name: myapp
 *     dependencies:
 *       **builder: any**
 *     **transformers:**
 *     **- builder:**
 *       **entry_points: test/all_tests.dart**
 */

import 'dart:async';

import 'package:barback/barback.dart';

import '../tool/unittest.dart';


class UnitTestTransformer extends Transformer {
  final BarbackSettings settings;

  UnitTestTransformer() : settings = null;
  UnitTestTransformer.asPlugin(this.settings);

  /**
   * Space-separated list of file extensions with leading `.` that are the
   * allowed for the primary inputs to this transformer.
   */
  @override
  String get allowedExtensions => ".dart";


  @override
  Future<bool> isPrimary(Asset input) {
    return super.isPrimary(input).then((res) {
      if (! res) {
        return false;
      }

      if (input.id.path.startsWith("test/")) {
        // files within the "test/" directory
        return new Future.value(true);
      }
      return new Future.value(false);
    });
  }


  @override
  Future apply(Transform transform) {
    // FIXME
    print("should run unit test on " + transform.primaryInput);
  }
}
