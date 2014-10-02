# Change History for builder.dart

## 0.2.1

**::Overview::**

Fixed the issue with the `FileEntityResource` factory returning a typed version
when the class itself is generic - this should now be called with the
`createFileEntityResource` method instead.  Note that users shouldn't be
directly calling this, but instead should use the type-safe versions
(`DirectoryResource.named` and `FileResource.named`).

Bug fixes.

**::Details::**

* Bug fixes:
    * (Bug #29)(test for https://github.com/groboclown/builder.dart/issues/29) -
      **'part of library_name' causes NoSuchMethodError**.  The stdout and
      stderr type have changed with the newer Dart releases, which makes the
      LineSplitter transformer no longer work.
    




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
