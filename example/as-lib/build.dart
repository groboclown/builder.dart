// test for https://github.com/groboclown/builder.dart/issues/29

library build;

import 'package:builder/builder.dart';
import 'package:builder/std.dart';

final dartAnalyzer = new DartAnalyzer("lint",
    description: "Check the Dart files for language issues",
    dartFiles: LIB_FILES);

main(List<String> args) {
  build(args);
}
