builder.dart Tools
==================

`builder.dart` provides some out-of-the-box tools to help with the construction
of builds.

These are the tools used by the declarative build style.  You can find the tasks
provided for procedural builds under the [tasks page](tasks.md).



Common Usage
------------

All tools share the same general invocation usage.



Delete
------

Deletes files and directories based on a [ResourceCollection](datatypes.md).



MkDir
-----

Creates an empty directory.



Exec
----

Runs a native application.



Copy
----



Relationship
------------

Defines an indirect relationship between one set of files and another.  For
example, in interpreted languages (such as Dart), the unit test execution only
directly depends upon the unit tests, because those are the files that it runs.
However, those unit tests have their own relationship to the source files that
they test.  This relationship can be described in a [Relationship] target.


DartAnalyzer
------------



UnitTests
---------



Dart2JS
-------



Data Types
==========

builder.dart uses a set of custom data types used by the various tools.  A few
are specific to certain tools, while others are generally used by all the
tools.

The common data types can be found [here](datatypes.md).

