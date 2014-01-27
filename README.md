builder.dart
============

General build tool for Dart projects.


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

    import "package:builder/builder.dart";

    bool useMachineInterface = false;

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
