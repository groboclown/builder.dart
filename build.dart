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

// The standard package layout definitions
import 'package:builder/std.dart';

final DirectoryResource OUTPUT_DIR = new DirectoryResource.named(".work/");
final DirectoryResource TEST_SUMMARY_DIR =
  OUTPUT_DIR.child("test-results/");
final DirectoryResource GEN_DOC_DIR = OUTPUT_DIR.child("docs/api/");

// File mapping
final unitTestSources = new Relationship("src-to-tests",
    description: "Unit tests covering source files",
    src: LIB_DIR, dest: TEST_DIR,
    translator: globTranslator("**/*.dart", "%%/*_test.dart"));


// --------------------------------------------------------------------
// Targets

final dartAnalyzer = new DartAnalyzer("lint",
    description: "Check the Dart files for language issues",
    dartFiles: new ResourceSet.from([
        new DirectoryCollection.everything(
          new DirectoryResource.named('lib')),
        TEST_FILES
      ], DART_FILE_FILTER));


final cleanOutput = new Delete("clean-output",
    description: "Clean the generated files",
    files: OUTPUT_DIR.everything(),
    onFailure: IGNORE_FAILURE);


// Commented out until the new unit test isolate stuff is fixed.
final unitTests = new UnitTests("test",
    description: "Run unit tests and generate summary report",
    testFiles: TEST_FILES,
    summaryDir: TEST_SUMMARY_DIR);


final docGen = new DocGen("docgen",
    description: "Generate API documentation",
    dartFiles: [ LIB_DIR.child("tool.dart"), LIB_DIR.child("make.dart"),
      LIB_DIR.child("builder.dart"), LIB_DIR.child("unittest.dart") ],
    excludeLibs: [ 'ansicolor' ],
    outDir: GEN_DOC_DIR);


// FOR TESTING - the builder project uses the "dart:io" package, which makes
// it incompatible for Dart2JS.
//final dart2js = new Dart2JS("dart2js",
//    description: "Convert the dart argparser to js",
//    phase: PHASE_DEPLOY,
//    dartFile: new FileResource.named("lib/src/argparser.dart"),
//    outDir: OUTPUT_DIR);

// FOR TESTING
final copy = new Copy.dir("export-docs",
    description: "Export documents into the work directory",
    src: DOC_DIR,
    dest: OUTPUT_DIR.child("docs/") as ResourceListable);


void main(List<String> args) {
  // Run the build
  build(args);
}


