// test for https://github.com/groboclown/builder.dart/issues/31

//import 'package:builder/unittest.dart';
import 'package:unittest/unittest.dart';
//import 'package:unittest/vm_config.dart';
import 'dart:io';

String readData() => new File('data/data.txt').readAsStringSync();

main(List<String> args, [ replyTo ]) {
  //selectConfiguration(replyTo, useVMConfiguration);

  var data = readData();
  test('any test', () {
    expect('test data', equals(data));
  });
}
