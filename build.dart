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



void main(List<String> args) {
  // All initialization is inside "main" to prevent lazy-loading issues.

  // --------------------------------------------------------------------
  // Directories and file sets
  final rootDir = filenameToResource(".");
  final libDir = filenameToResource("lib");
  final mainDartSrc = new ListableResourceColection(libDir,
      (r) => (! r.isDirectory) && r.name.endsWith(".dart"));
  
  final testDir = filenameToResource("test");
  final testDartSrc = new ListableResourceColection(testDir,
      (r) => (! r.isDirectory) && r.name.endsWith(".dart"));
  
  final allDartSrc = new ResourceSet([ mainDartSrc, testDartSrc ]);
  
  
  
  // --------------------------------------------------------------------
  // Targets
  
  final dartAnalyzer = new DartAnalyzer("lint",
      description: "Check the Dart files for language issues",
      dartFiles: allDartSrc,
      pacakgeRoot: rootDir);

  build(args);
}


