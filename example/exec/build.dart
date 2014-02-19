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

/**
 * An example build showing how to use the Exec build tool.
 */

// The build library
import '../../lib/builder.dart';

// The standard package layout definitions
import '../../lib/std.dart';

// The tools to run
final echoWindows = new Exec("echo-windows",
  description: "run a shell command with windows",
  cmd: new FileEntityResource.asFile("cmd"),
  platform: "windows",
  args: [ "/c", "echo", "hello, windows" ]);

final echoNix = new Exec("echo-nix",
  description: "run a shell command with a *nix type system",
  cmd: new FileEntityResource.asFile("bash"),
  args: [ "-c", "echo", "hello, bash" ]);

final echo = new VirtualTarget("echo",
  description: "Run the echo command on the correct platform",
  depends: [ 'echo-windows', 'echo-nix' ]);


// The primary build
void main(List<String> args) {
  // Run the build
  build(args);
}
