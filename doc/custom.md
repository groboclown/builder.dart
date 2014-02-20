Creating a Custom Build Tool
============================

Though the builder.dart build system provides several build tools to get you
started in creating the correct automated build for your needs, these won't
cover every situation, and you may find that you need to create a new build
tool.


Define the Class and Constructor
--------------------------------

You can create new custom build tools by followings a simple patern.  First,
create a class that extends `BuildTool`:

    library mylib.build

    import 'package:builder/tool.dart';

    class MyLibBuilder extends BuildTool {
    }

You will need to pass in some required arguments to the super class
constructor, and the pattern follows like this:

    factory MyLibBuilder(String name,
        { String description: "", String phase: PHASE_BUILD,
        List<String> depends, arg1 }) {

      var pipe = ...;

      var targetDef = BuildTool.mkTargetDef(name, description, phase, pipe,
          depends, <String>[]);
      return new MyLibBuilder._(name, targetDef, phase, pipe, arg1);
    }

    MyLibBuilder._(String name, TargetDef targetDef, String phase, Pipe pipe,
        arg1) :
      this.arg1 = arg1,
      super(name, targetDef, phase, pipe);

The factory constructor should always take a `String name`,
`String description`, `String phase`, and a `List<String> depends` arguments.
Additional arguments should also be named parameters, to make the build file
clear as to the meaning behind each parameter.

The `phase` argument should default to a common-sense build phase in which
this target usually runs.  The builder tool splits up the build into logical
blocks of "phases" which define an ordered flow to the build, and force actions
like "delete" to always run before the tool that generates the output.

The phase may be one of the following values:

* `PHASE_CLEAN` - removes files and other remnants from old builds.
* `PHASE_BUILD` - constructs the base files and performs quick checks to
   ensure the integrety of the built files.
* `PHASE_ASSEMBLE` - copy files into a layout that can be used for deploying
   the package.
* `PHASE_DEPLOY` - push the assembled files to a deployment environment.

The tool should create a `Pipe` object if it creates or uses files for its
operation.  The pipe tells the builder how to thread together the execution
order based on how different tools consume the files.  Pipes are described
below.

The `depends` argument is a list of other build tool names that the user can
pass in to force this tool to run after them.  The call to
`BuildTool.mkTargetDef` uses this dependency list, and an additional list of
strings for the weak dependencies (the example above just passed it as
`<String>[]`), and the pipe, creates the correct dependency chain.


Performing The Action
---------------------

Next, in order to have your new build tool actually do something, you need
to override the `start` method.

    @override
    Future<Project> start(Project project) {
      project.logger.info("Running my tool!");
      return new Future<Project>.sync(() => project);
    }

The start method can do whatever is needed to perform the action.  It is
called when the action should begin, and needs to return a `Future` that
completes when the tool finishes running.  It should never return
`null`.


Pipes
-----




Errors
------


Project
-------


Resources
---------
