# Change History for builder.dart


## 0.2.4

**::Overview::**

Bug fixes

**::Details::**

* Bug Fixes:
    * Tighter version constraint on exported package (#33)


## 0.2.3

**::Overview::**

Bug fixes.

**::Details::**

* Bug fixes:
    * Removed extra message `Only libraries can be analyzed.` from the
      DartAnalyzer tool.  This can be disabled by setting a 'quiet' flag in
      the tool to `false`.
    * Switched the dartanalyzer to take a `Sink` instead of a `StreamController`
      for the messages.  The dartanalyzer tool also closes the sink when the
      processing completes.
    * Fixed the dartanalyzer where it was incorrectly interpreting the Windows
      directory seperator (\) as an escape sequence.
* API changes
    * Changed the `Pipe` interface so it returns `Iterable` rather than
      `List` objects.
    * Changed the `ResourceCollection` interface so it returns `Iterable` rather
      than a `List` of resources.
    * Changed the `ResourceListable` interface so it returns `Iterable` rather
      than a `List` of resources.
* Improvements
    * Started work on the dirty detection code.  It isn't being used at the
      moment.


## 0.2.2

**::Overview::**

Fixes bugs around how unit tests are run, so that they no longer hang the
build.

**::Details::**

* Minor doc updates
* Bug fixes:
    * (Bug #30)(https://github.com/groboclown/builder.dart/issues/30) -
      **build with UnitTests does not terminate**.
      Fixed by moving the unit test execution into their own process.
      This was necessary due to the current Dart implementation of Isolates
      not being very robust.
    * (Bug #31)(https://github.com/groboclown/builder.dart/issues/31) -
      **UnitTests do not run in their own directory**.
      Fixed with the move to running unit tests in a separate Process.


## 0.2.1

**::Overview::**

Fixed the issue with the `FileEntityResource` factory returning a typed version
when the class itself is generic.  This was done by making that class be
nothing but a parent super-class for the new `AbstractFileEntityResource` that
does the real work, and which has the correct templating.

Bug fixes.

**::Details::**

* Fixed the `DartAnalyzer` tool implementation to run all the input files in
  a single execution of dartanalyzer.  This has the benefits of not duplicating
  the execution over the same file multiple times, and it only launches an
  external process once.
* Fixed the issue with the `FileEntityResource` factory returning a typed
  version when the class itself is generic.  This was done by making that class
  be nothing but a parent super-class for the new `AbstractFileEntityResource`
  that does the real work, and which has the correct templating.
* Bug fixes:
    * (Bug #29)(https://github.com/groboclown/builder.dart/issues/29) -
      **'part of library_name' causes NoSuchMethodError**.  The stdout and
      stderr type have changed with the newer Dart releases, which makes the
      LineSplitter transformer no longer work.
    * (Bug #30)(https://github.com/groboclown/builder.dart/issues/30) -
      **build with UnitTests does not terminate**.
      Partial fix.  The Isolate-based invocation is improved, but still doesn't
      fix this issue in all cases.



## 0.2.0

**::Overview::**

Bug fix around the transformer. Updated the library to work with the
newer Dart APIs.  Moved from using dartdoc to docgen.

**::Details::**

* Old DartDoc class is deprecated.  Use DocGen instead.
* Added the DocGen tool.
* Removed dartdoc from the transformers.  Bug repored by maiermic.


## 0.1.0

**::Overview::**

Initial release
