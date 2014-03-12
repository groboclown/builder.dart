builder.dart Tools
==================

`builder.dart` provides some out-of-the-box tools to help with the construction
of builds.

These are the tools used by the declarative build style.  You can find the tasks
provided for procedural builds under the [tasks page](tasks.md).

`builder.dart` uses a set of custom data types used by the various tools.  A few
are specific to certain tools, while others are generally used by all the
tools.  The common data types can be found [here](datatypes.md).




Common Usage
------------

All tools share the same general invocation usage.

 * **(implied first argument)** (`String`) the name of the tool, as invoked
    from the command line.
 * **description** (`String`) description about the purpose of the tool.
    Displayed as a help message with the name of the tool.
 * **phase** (`String`) override the default phase of the tool.  This describes
    the grouping of when the tool is run in relation to other tools.
 * **depends** (`List<String>`) list of tools that this tool directly depends
    upon.


## Delete
- - -

Deletes files and directories based on a [ResourceCollection](datatypes.md).

**Default Phase:** `PHASE_CLEAN`

#### Supported Arguments:

 * **files** (`ResourceCollection` *required*) collection of the files and
        directories to remove.
 * **onFailure** (`FailureMode`) how to handle failures to delete.


## MkDir
- - -

Creates an empty directory.  Directories are created when needed by other files,
so this tool should only be used when an empty directory is explicitly needed.

**Default Phase:** `PHASE_BUILD`

#### Supported Arguments:

 * **dir** (`Resource` *required*) directory to create
 * **onFailure** (`FailureMode`) how to handle problem creating
        directory.


## Exec
- - -

Runs a native application.

**Default Phase:** `PHASE_BUILD`

#### Supported Arguments:

 * **onFailure** (`FailureMode`) how to handle problems



## Copy
- - -

Copies files and other resources.  Unlike other tools, it has different
constructors to specify the exact kind of copy requested.

**Default Phase:** `PHASE_BUILD`

#### Supported Arguments:

 * **onFailure** (`FailureMode`) how to handle problem creating
        directory.



## Relationship
- - -

Defines an indirect relationship between one set of files and another.  For
example, in interpreted languages (such as Dart), the unit test execution only
directly depends upon the unit tests, because those are the files that it runs.
However, those unit tests have their own relationship to the source files that
they test.  This relationship can be described in a [Relationship] target.


## DartAnalyzer
- - -

Runs the `dartanalyzer` tool.

**Default Phase:** `PHASE_BUILD`

#### Supported Arguments:

 * **dir** (`Resource` *required*) directory to create
 * **onFailure** (`FailureMode`) how to handle problem creating
        directory.



## UnitTests
- - -

Runs unit tests.

**Default Phase:** `PHASE_BUILD`

#### Supported Arguments:

 * **dir** (`Resource` *required*) directory to create
 * **onFailure** (`FailureMode`) how to handle problem creating
        directory.



## Dart2JS
- - -

Runs the `dart2js` tool.

**Default Phase:** `PHASE_BUILD`

#### Supported Arguments:

 * **dir** (`Resource` *required*) directory to create
 * **onFailure** (`FailureMode`) how to handle problem creating
        directory.


## DartDoc
- - -

_Note: this tool is only supported in Dart versions 1.1, and is removed as of Dart 1.2._
