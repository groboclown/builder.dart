builder.dart
============

General build tool for Dart projects.


Status
======

The tool is just in the beginnings.  The basic API has been established.

* Need to create the loggers to be compatible with both the machine interface and human interface.
* Add proper target execution ordering (a simple topological sort will do).
* Add more helper libraries to make creation of builds easier: dart, dart2js, pub, zip, unzip.
* Currently, this is using a procedural build process.  Work has begun to allow for a declarative build process.
* Update this documentation as work progresses.


Adding The Builder To Your Project
==================================

You first need to add the builder library to your `pubspec.yaml` file:

    name: my_app
    author: You
    version: 1.0.0
    description: My App
    dependencies:
      args: ">=0.9.0"

    dev_dependencies:
      builder: ">=0.0.1"
      unittest: ">=0.9.3"

Because the library is only used to build the project, it should belong in the
`dev_dependencies` section, not `dependencies`.

Next, in accordance with the [dart build file standard](https://www.dartlang.org/tools/editor/build.html),
create the file `build.dart` in the root project directory.  It should look
like this:

    import "package:builder/make.dart";

    void main(List<String> args) {
      make(Build, args);
    }


    class Build {
      @target.main('default project')
      void main(Project p) {
        ...
      }

      @target('full build', depends: ['clean', 'main'])
      void full(Project p) {
        ...
      }

      @target('clean the project')
      void clean(Project p) {
        ...
      }

      @target('bundle the files together into a distributable', depends: ['main'])
      void bundle(Project p) {
        ...
      }

      @target('deploy the project to the web server', depends: ['bundle'])
      void deploy(Project p) {
        ...
      }
    }

Note the special `@target` annotation to denote a build target.  This annotation
takes a text description (`String`) as an argument, and an optional list of
target names (`List<String>`) as the dependent targets that need to run before
this one.

Running The Build
=================

...


Helper Tools
============


builder/resource.dart
---------------------

...

builder/dart.dart
-----------------

...



License
=======

Released under the MIT license.

    The MIT License (MIT)

    Copyright (c) 2014 Groboclown

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
    the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

