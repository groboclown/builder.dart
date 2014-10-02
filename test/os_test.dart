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

library os_test;


import 'package:builder/unittest.dart';
import 'package:unittest/vm_config.dart';
import '../lib/src/os.dart';


test_splitPath() {
  test('empty path', () => expect(
      splitPath("", false, r"[\:\;\:]"),
      equals(<String>[])
  ));
  test('single path', () => expect(
      splitPath("a", true, r"[\:\;\:]"),
      equals(<String>[ "a" ])
  ));
  test('simple unix path on windows', () => expect(
      splitPath("a/b:c/d", true, r"[\:\;\:]"),
      equals(<String>[ "a/b", "c/d" ])
  ));
  test('simple unix path on unix', () => expect(
      splitPath("a/b:c/d", false, r"[\:\;\:]"),
      equals(<String>[ "a/b", "c/d" ])
  ));
  test('simple dos path on unix', () => expect(
      splitPath("a\\b;c\\d", false, r"[\:\;\:]"),
      equals(<String>[ "a\\b", "c\\d" ])
  ));
  test('simple dos path on windows', () => expect(
      splitPath("a\\b;c\\d", true, r"[\:\;\:]"),
      equals(<String>[ "a\\b", "c\\d" ])
  ));
  test('full dos file on unix', () => expect(
      splitPath("c:\\a\\b", false, r"[\:\;\:]"),
      equals(<String>[ "c", "\\a\\b" ])
  ));
  test('full dos file on windows', () => expect(
      splitPath("c:\\a\\b", true, r"[\:\;\:]"),
      equals(<String>[ "c:\\a\\b" ])
  ));
  test('two full dos file on unix', () => expect(
      splitPath("c:\\a\\b;d:\\abc\\ddd", false, r"[\:\;\:]"),
      equals(<String>[ "c", "\\a\\b", "d", "\\abc\\ddd" ])
  ));
  test('two full dos file on windows', () => expect(
      splitPath("c:\\a\\b;d:\\abc\\ddd", true, r"[\:\;\:]"),
      equals(<String>[ "c:\\a\\b", "d:\\abc\\ddd" ])
  ));
  test('mixed path on unix', () => expect(
      splitPath("cabc:\\a\\b:1:\\b:a:;d:\\abc\\ddd", false, r"[\:\;\:]"),
      equals(<String>[ "cabc", "\\a\\b", "1", "\\b", "a", "d", "\\abc\\ddd" ])
  ));
  test('mixed path on windows', () => expect(
      splitPath("cabc:\\a\\b:1:\\b:a:;d:\\abc\\ddd", true, r"[\:\;\:]"),
      equals(<String>[ "cabc", "\\a\\b", "1", "\\b", "a", "d:\\abc\\ddd" ])
  ));
}


all_tests() {
  test_splitPath();
}



main(List<String> args, [ replyTo ]) {
  args = setConfiguration(args, replyTo, useVMConfiguration);
  all_tests();
  if (!args.isEmpty) {
    filterTests(args[0]);
  }
}
