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

library builder.std;

/**
 * Standard build constants for the normal dart project layout, based on
 * (package layout conventions)[http://pub.dartlang.org/doc/package-layout.html].
 */

import 'resource.dart';
import 'dart:io';

final DirectoryResource ROOTDIR = new DirectoryResource(Directory.current);

ResourceTest DART_FILE_FILTER = (r) =>
  (r.exists && DEFAULT_IGNORE_TEST(r) && r.name.toLowerCase().endsWith(".dart"));


final DirectoryResource ASSET_DIR = filenameAsDir(ROOTDIR, "asset");
final ResourceCollection ASSET_FILES = new DeepListableResourceCollection(
    ASSET_DIR, DEFAULT_IGNORE_TEST, DEFAULT_IGNORE_TEST);

final DirectoryResource BENCHMARK_DIR = filenameAsDir(ROOTDIR, "benchmark");
final ResourceCollection BENCHMARK_FILES = new DeepListableResourceCollection(
    BENCHMARK_DIR, DART_FILE_FILTER, SOURCE_RECURSION_TEST);

final DirectoryResource BIN_DIR = filenameAsDir(ROOTDIR, "bin");
final ResourceCollection BIN_FILES = new DeepListableResourceCollection(
    BIN_DIR, DEFAULT_IGNORE_TEST, SOURCE_RECURSION_TEST);

final DirectoryResource DOC_DIR = filenameAsDir(ROOTDIR, "doc");
final ResourceCollection DOC_FILES = new DeepListableResourceCollection(
    BIN_DIR, DEFAULT_IGNORE_TEST, DEFAULT_IGNORE_TEST);

final DirectoryResource EXAMPLE_DIR = filenameAsDir(ROOTDIR, "example");
final ResourceCollection EXAMPLE_FILES = new DeepListableResourceCollection(
    EXAMPLE_DIR, DEFAULT_IGNORE_TEST, SOURCE_RECURSION_TEST);

final DirectoryResource LIB_DIR = filenameAsDir(ROOTDIR, "lib");
final ResourceCollection LIB_FILES = new DeepListableResourceCollection(
    LIB_DIR, DART_FILE_FILTER, SOURCE_RECURSION_TEST);

final DirectoryResource TEST_DIR = filenameAsDir(ROOTDIR, "test");
final ResourceCollection TEST_FILES = new DeepListableResourceCollection(
    TEST_DIR, DART_FILE_FILTER, SOURCE_RECURSION_TEST);

final DirectoryResource TOOL_DIR = filenameAsDir(ROOTDIR, "tool");
final ResourceCollection TOOL_FILES = new DeepListableResourceCollection(
    EXAMPLE_DIR, DEFAULT_IGNORE_TEST, SOURCE_RECURSION_TEST);

final DirectoryResource WEB_DIR = filenameAsDir(ROOTDIR, "web");
final ResourceCollection WEB_FILES = new DeepListableResourceCollection(
    WEB_DIR, DEFAULT_IGNORE_TEST, DEFAULT_IGNORE_TEST);


final ResourceCollection DART_FILES = new ResourceSet.from([
    BENCHMARK_FILES, BIN_FILES, DOC_FILES, EXAMPLE_FILES, LIB_FILES,
    TEST_FILES, TOOL_FILES
]);
