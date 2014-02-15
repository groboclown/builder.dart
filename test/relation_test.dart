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

import 'package:builder/unittest.dart';
import 'package:unittest/vm_config.dart';

import '../lib/src/tool/relation.dart';

test_GlobTranslator() {
  group("globTranslator", () {
    test('single-star, no path', () {
      expect(globTranslator("*.java", "*.class")("A.java"),
        equals("A.class"));
    });
    test('single-star, simple path', () {
      expect(globTranslator("a/*.java", "b/*.class")("a/A.java"),
      equals("b/A.class"));
    });
    test('single-star, no match', () {
      expect(globTranslator("*.java", "*.class")("A.dart"),
      equals(null));
    });
  });
}


all_tests() {
  test_GlobTranslator();
}



main(List<String> args, [ replyTo ]) {
  selectConfiguration(replyTo, useVMConfiguration);
  all_tests();
  if (!args.isEmpty) {
    filterTests(args[0]);
  }
}
