// test for https://github.com/groboclown/builder.dart/issues/31

import 'package:unittest/unittest.dart';
import 'dart:io';

main(List<String> args) {
  test('any test', () {
    expect('test data', equals("test data"));
  });
}
