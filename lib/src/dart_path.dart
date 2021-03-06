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

library builder.src.tool.dart_path;

/**
 * Defines paths related to dart's SDK.
 */

import 'dart:io';
import 'package:path/path.dart' as path;

final List<String> DART_PATH = <String>[
    (Platform.environment['DART_SDK'] == null
    ? null
    : path.join(Platform.environment['DART_SDK'], "bin")),
    (Platform.environment['DART_HOME'] == null
    ? null
    : path.join(Platform.environment['DART_HOME'], "bin" ))];
final String DART_ANALYZER_NAME = "dartanalyzer";
final String DART2JS_NAME = "dart2js";
final String DOCGEN_NAME = "docgen";
final String DART_NAME = "dart";

