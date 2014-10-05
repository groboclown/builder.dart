// test for https://github.com/groboclown/builder.dart/issues/29
// test for https://github.com/groboclown/builder.dart/issues/31

library build;

import 'package:builder/builder.dart';
import 'package:builder/std.dart';

final DirectoryResource OUTPUT_DIR = new FileEntityResource(".work/");
final DirectoryResource TEST_SUMMARY_DIR = OUTPUT_DIR.child("test-results/");

final unitTests = new UnitTests("test",
    description: "Run unit tests and generate summary report",
    testFiles: TEST_FILES,
    summaryDir: TEST_SUMMARY_DIR,
    runInTestDir: true);

final dartAnalyzer = new DartAnalyzer("lint",
    description: "Check the Dart files for language issues",
    dartFiles: new ResourceSet.from([ TEST_FILES, LIB_FILES ]));

main(List<String> args) {
  build(args);
}
