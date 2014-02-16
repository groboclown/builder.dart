builder.dart Tools
==================

`builder.dart` provides some out-of-the-box tools to help with the construction
of builds.





Delete
------

*import 'package:builder/std.dart*

Deletes files and directories based on a [ResourceCollection].



MkDir
-----

*import 'package:builder/std.dart*


Exec
----

*import 'package:builder/std.dart*


DartAnalyzer
------------

*import 'package:builder/dart.dart*


UnitTests
---------

*import 'package:builder/dart.dart*




Data Types
==========

builder.dart uses a set of custom data types used by the various tools.  A few
are specific to certain tools, while others are generally used by all the
tools.


Resource
--------

A [Resource] object references streamable object or a container for streamable
objects.  Commonly, this refers to files and directories, but can also refer
to URI network resources.
