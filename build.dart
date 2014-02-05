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

library build;

// The build library
import 'package:builder/builder.dart';

// The standard dart language tools
import 'package:builder/dart.dart';

// The standard package layout definitions
import 'package:builder/std.dart';

final DirectoryResource OUTPUT_DIR = new FileEntityResource.asDir(".work/");
final DirectoryResource TEST_SUMMARY_DIR =
  OUTPUT_DIR.child("test-results/");



// --------------------------------------------------------------------
// Targets

final dartAnalyzer = new DartAnalyzer("lint",
    description: "Check the Dart files for language issues",
    dartFiles: DART_FILES);


final cleanOutput = new Delete("clean-output",
    description: "Clean the generated files",
    files: new DeepListableResourceCollection(OUTPUT_DIR, null, null, true));


final unitTests = new UnitTests("test",
    description: "Run unit tests and generate summary report",
    testFiles: TEST_FILES,
    summaryDir: TEST_SUMMARY_DIR);


void main(List<String> args) {
  // Run the build
  build(args);
}


