builder.dart
============

General build tool for Dart projects.  It supports both a *procedural* and *declarative* style.



Status
======

The tool is just in the beginnings, but already it builds itself.

* Add more helper libraries to make creation of builds easier: dart, dart2js, pub, zip, unzip.
* Update this documentation as work progresses.
* Add support for testing frameworks like DumpRenderTree (used by Dart team's [web-ui](https://github.com/dart-lang/web-ui) project)
* Work on publicity and integration with tools like [drone.io](http://docs.drone.io/dart.html)



Adding The Builder To Your Project
==================================

Regardless of whether you go the procedural or declarative route, you first need to add
the builder library to your `pubspec.yaml` file in the `dev_dependencies` section.

    name: my_app
    author: You
    version: 1.0.0
    description: My App

    dev_dependencies:
      builder: ">=0.0.1"

The library belongs in the `dev_dependencies` section, not `dependencies`,
because it is only used to build the project.

Next, you need to decide if you're going to take the procedural or declarative
route, and make your build file accordingly.


Declarative
-----------

A *declarative* build works by declaring what build actions depend on each other,
then it's up to the build library to decide what should actually be run.  You lose
a bit of clarity in the build (the execution plan is no longer just top to bottom),
but you don't need to worry about lots of minute details.

The build structure is broken into phases, which are major groupings of events.  By
default, there's _clean_, _build_, _assemble_, and _deploy_ (defined in
`builder/tool.dart`).  Then, each build target defines which phase it run in,
and a connection of resources it consumes and resources it generates.  These two
definitions give the build target an implicit ordering.

Your build will have this kind of structure:

    // the build file should be in the "build" library
    library build;

    // The build library
    import 'package:builder/builder.dart';

    // The standard dart language tools
    import 'package:builder/dart.dart';

    // --------------------------------------------------------------------
    // Directories and file sets
    final libDir = ROOT_DIR.child("lib/");
    final mainDartSrc = new DeepListableResourceCollection.files(libDir,
        (r) => r.name.endsWith(".dart"));

    final testDir = ROOT_DIR.child("test/");
    final testDartSrc = new DeepListableResourceCollection.files(testDir,
        (r) => r.name.endsWith(".dart"));

    final allDartSrc = new ResourceSet.from([ mainDartSrc, testDartSrc ]);

    // --------------------------------------------------------------------
    // Targets

    final dartAnalyzer = new DartAnalyzer("lint",
        description: "Check the Dart files for language issues",
        dartFiles: allDartSrc);

    
    // Run the build
    void main(List<String> args) {
      build(args);
    }

Each constructed build tool in the `build` library will be picked up as a
target to run.


Procedural
----------


You first need to add the builder library to your `pubspec.yaml` file:



Note: due to this change, any build of your project will still require a new
copy of the code to run `pub install` to pull in the builder library.

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

The builder library is designed for use from within the Dart Editor tool, but
it can also be run from the command-line.



Run the default target:

`dart -c build.dart`


Discover the available targets:

`dart build.dart --help`


Run the clean target:

`dart build.dart --clean`



Helper Tools
============


builder/resource.dart
---------------------

...

builder/dart.dart
-----------------

...


Making Your Own Tool
--------------------


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

