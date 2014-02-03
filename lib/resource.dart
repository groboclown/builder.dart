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

library builder.resource;

/**
 * Handles file and other resources used by the build in an abstract way.
 */

import 'dart:io';
import 'dart:collection';
import 'dart:convert';
import 'dart:async';

import 'src/exceptions.dart';

bool CASE_SENSITIVE = true;


/**
 * Generic definition of a read/write resource.
 */
abstract class Resource<T extends ResourceListable> {
  /**
   * The simple name of the resource.  For file objects, this represents the
   * file name without the parent directory.  For URI objects, this is the
   * file name without the path or scheme information.
   */
  String get name;

  /**
   * The full name of the resource, including parent information.
   */
  String get fullName;

  /**
   * Returns `true` if the [#readAsBytes()] and [#readAsString()] calls are
   * supported by this [Resource].
   */
  bool get readable;

  /**
   * Returns `true` if the [#writeAsBytes()] and [#writeAsString()] calls are
   * supported by this [Resource].
   */
  bool get writable;

  /**
   * Returns `true` if this [Resource] actually exists.
   */
  bool get exists;

  /**
   * The parent [Resource] of this one.  If this [Resource] already represents
   * the top-level, then it returns `this`.
   */
  T get parent;

  /**
   * Attempt to delete this [Resource].  Set [recursive] to `true` to attempt
   * to delete this resource and its children.
   *
   * Returns `true` if this [Resource] was removed.  In the case of
   * [recursive] = `true`, a `false` return result may indicate a partial failure,
   * where potentially some or all of the children may have been deleted, but
   * this instance still remains.
   */
  // default implementation returns false.
  bool delete(bool recursive) {
    return false;
  }

  /**
   * Read the contents of this [Resource] as binary bytes.  If
   * [#readable] is `false`, then this will throw an [Exception].
   */
  // default implementation throws an exception.
  List<int> readAsBytes() {
    throw new Exception("readAsBytes not supported on " + name);
  }

  /**
   * Read the contents of this [Resource] as character data, using `encoding`
   * to encode the binary data as characters (defaults to the system encoding).
   * If [#readable] is `false`, then this will throw an [Exception].
   */
  // default implementation throws an exception.
  String readAsString({ Encoding encoding: null }) {
    throw new Exception("readAsString not supported on " + name);
  }


  /**
   * Write the binary byte `data` to this [Resource].  If
   * [#writable] is `false`, then this will throw an [Exception].
   */
  // default implementation
  void writeBytes(List<int> data) {
    throw new Exception("writeAsBytes not supported on " + name);
  }

  /**
   * Write the character `data` to this [Resource], using `encoding`
   * to encode the characters as binary data (defaults to the system encoding).
   * If [#writable] is `false`, then this will throw an [Exception].
   */
  // default implementation
  void writeString(String data, { Encoding encoding: null }) {
    throw new Exception("writeAsString not supported on " + name);
  }


  /**
   * Opens the [Resource] for asynchronous access.  Users of this method
   * must follow the conventions of [RandomAccessFile], and implementations
   * of [Resource] that provide this method must implement the
   * [RandomAccessFile] API.  Note that [RandomAccessFile.setPosition(int)]
   * may throw an exception if the position is after the current position
   * (no going backwards).
   *
   * If the [mode] is `READ` or `APPEND`, and the [readable] property returns
   * `false`, then this will throw an [Exception].  Likeise, if the mode is
   * `WRITE` or `APPEND`, and the [writable] property returns `false`, then this
   * will throw an [Exception].
   */
  // default implementation
  Future<RandomAccessFile> open(FileMode mode) {
    throw new Exception("open not supported on " + name);
  }


  /**
   * Returns `true` if this resource contain the other resource, or if it is
   * the same object.  If the instance represents a [ResourceListable]
   * object, then it should check against all the actual [Resource] instances
   * it lists.  If the instance represents a container [Resource], but one
   * that *only* represents the container, and not sub-elements, then it
   * should only match on equality.
   *
   * Default implementation returns the [operator ==] value.
   */
  bool contains(Resource other) {
    return this == other;
  }


  /**
   * Returns `true` if either this [Resource] [#contains(Resource)] the
   * other [Resource], or if the other [Resource] [#contains(Resource)] this
   * one.
   */
  bool matches(Resource other) {
    return (this.contains(other) || other.contains(this));
  }


  /**
   * Checks if this [Resource] represents the exact same [Resource] as `t`.
   */
  @override
  bool operator ==(Resource t) {
    if (t == null) {
      return false;
    }
    return fullName == t.fullName;
  }
  
  @override
  String toString() {
    return fullName;
  }
}


/**
 * Interface (Really, a mixin, but the mixin syntax in Dart does not currently
 * support generics).
 *
 * A kind of [Resource] that contains other resources.
 */
abstract class ResourceListable<T extends Resource> extends Resource {
  List<T> list();

  /**
   * Return the child from inside this [Resource].  It does not have to be
   * returned by [#list()], in the case that something requests a new
   * resource.
   *
   * The [name] is relative to this [Resource].
   *
   * If the [name] cannot be represented as a child [Resource], then this
   * method returns `null`.
   */
  T child(String name);
}


/**
 * A collection of [Resource] instances, but not necessarily itself a
 * [Resource].  The entries may be dynamically loaded, and may change
 * from call to call.
 */
abstract class ResourceCollection {
  List<Resource> entries();
}


class SimpleResourceCollection extends ResourceCollection {
  final List<Resource> _entries;

  SimpleResourceCollection(List<Resource> entries) :
    _entries = new UnmodifiableListView<Resource>(entries);

  SimpleResourceCollection.single(Resource entry) :
      _entries = new UnmodifiableListView<Resource>(<Resource>[ entry ]);

  @override
  List<Resource> entries() => this._entries;
}



abstract class AbstractResourceCollection extends ResourceCollection {
  List<Resource> _entries;

  @override
  List<Resource> entries() {
    if (_entries == null) {
      _entries = new UnmodifiableListView<Resource>(findResources());
    }
    return _entries;
  }


  List<Resource> findResources();


  void reset() {
    _entries = null;
  }

}



typedef bool ResourceTest(Resource r);

final List<RegExp> DEFAULT_IGNORE_NAMES = <RegExp>[
    new RegExp(r"^CVS[/\\]?$"),
    new RegExp(r"^\..*$")
];
final List<RegExp> DEFAULT_SOURCE_IGNORE_NAMES = <RegExp>[
    new RegExp(r"^packages[/\\]?$")
];




/**
 * Ignores all the names in the [RegExp] list [DEFAULT_IGNORE_NAMES].
 */
final ResourceTest DEFAULT_IGNORE_TEST = (f) =>
! DEFAULT_IGNORE_NAMES.any((m) => m.hasMatch(f.name));

/**
 * Ignores all the names in the [RegExp] list [DEFAULT_IGNORE_NAMES],
 * as well as the [DEFAULT_SOURCE_IGNORE_NAMES] list.
 */
final ResourceTest SOURCE_RECURSION_TEST = (f) =>
(! DEFAULT_SOURCE_IGNORE_NAMES.any((m) => m.hasMatch(f.name)) &&
! DEFAULT_IGNORE_NAMES.any((m) => m.hasMatch(f.name)));





class ResourceSet extends ResourceCollection {
  final List<ResourceCollection> _children = <ResourceCollection>[];
  ResourceTest filter;

  ResourceSet([ ResourceTest filter]) : this.filter = filter;

  ResourceSet.from(List<ResourceCollection> rc,
      [ ResourceTest filter]) : this.filter = filter {
    addAll(rc);
  }

  void add(ResourceCollection rc) {
    _children.add(rc);
  }

  void addAll(List<ResourceCollection> rc) {
    _children.addAll(rc);
  }

  void remove(ResourceCollection rc) {
    _children.remove(rc);
  }

  @override
  List<Resource> entries() {
    var ret = <Resource>[];
    for (ResourceCollection rc in _children) {
      var kids = rc.entries();
      if (filter != null) {
        kids = kids.where(filter);
      }
      ret.addAll(kids);
    }
    return ret;
  }

}



class ListableResourceCollection extends AbstractResourceCollection {
  final ResourceListable res;
  final ResourceTest resourceTest;

  ListableResourceCollection(this.res,
      [ this.resourceTest ]) {
    if (res == null) {
      throw new BuildSetupException("null ResourceListable");
    }
    //print("[ListableResourceCollection] " + res.toString() + " -> " + res.list().toString());
  }

  Iterable<Resource> findResources() {
    var ret = res.list();
    if (resourceTest != null) {
      ret = ret.where(resourceTest);
    }
    return ret;
  }
}


class DeepListableResourceCollection extends ListableResourceCollection {
  ResourceTest recurseTest;
  
  
  factory DeepListableResourceCollection.files(ResourceListable res,
      ResourceTest fileTest) {
    //ResourceTest resTest = (f) {
    //    print("Checking " + f.name + ": directory? " + f.isDirectory.toString() + "; fileTest? " + fileTest(f).toString());
    //    if (f.isDirectory && ! (f is DirectoryResource)) { print(" - but it's not a DirectoryResource!"); }
    //    return fileTest(f);
    //};
    ResourceTest recurseTest = DEFAULT_IGNORE_TEST;
    return new DeepListableResourceCollection(res, fileTest, recurseTest);
  }
  
  
  /**
   * `resourceTest` is for deciding whether a [Resource] should be added to
   * the output or not.  `recurseTest` is for deciding whether a
   * [ResourceListable] should have its contents examined.
   */
  DeepListableResourceCollection(ResourceListable res, [ ResourceTest resourceTest,
    ResourceTest recurseTest ]) :
    this.recurseTest = recurseTest,
    super(res, resourceTest);
  

  Iterable<Resource> findResources() {
    Set<Resource> ret = new Set<Resource>();
    Set<ResourceListable> visited = new Set<ResourceListable>();
    addMore(res, ret, visited);
    //print(res.name + ": " + ret.toString());
    return ret;
  }
  
  void addMore(ResourceListable listable, Set<Resource> ret,
      Set<ResourceListable> visited) {
    visited.add(listable);
    //print(res.name + "->" + listable.name);
    for (Resource child in listable.list()) {
      if (child is ResourceListable) {
        if (! visited.contains(child) &&
            (recurseTest == null || recurseTest(child))) {
          addMore(child, ret, visited);
        }
        //else { print("   skipped " + child.name); }
      } else if (resourceTest == null || resourceTest(child)) {
        //print("    <="+child.name);
        ret.add(child);
      }
    }
  }
  
}





// ===========================================================================
// File system implementation


abstract class FileEntityResource<T extends FileSystemEntity>
    extends Resource<DirectoryResource> {

  final T entity;

  FileEntityResource(this.entity);

  @override
  String get name => _filenameOf(entity.absolute);

  @override
  String get fullName => entity.absolute.path;

  @override
  bool get readable {
    FileStat fileStat = entity.statSync();
    if (fileStat.type == FileSystemEntityType.NOT_FOUND) {
      return parent.readable;
    }
    int mode = fileStat.mode;
    // assume that, if any read bit is set, we can read it
    return ((mode & 292) != 0); // 444 oct
  }

  @override
  bool get writable {
    FileStat fileStat = entity.statSync();
    if (fileStat.type == FileSystemEntityType.NOT_FOUND) {
      return parent.readable;
    }
    int mode = fileStat.mode;
    // assume that, if any write bit is set, we can write it
    return ((mode & 146) != 0); // 222 oct
  }

  @override
  bool get exists => entity.existsSync();

  @override
  bool get isLink => entity is Link;

  @override
  DirectoryResource get parent => new DirectoryResource(entity.parent);

  @override
  bool delete(bool recursive) {
    try {
      entity.deleteSync(recursive: recursive);
      return true;
    } catch(e) {
      return false;
    }
  }

  
  String _filenameOf(FileSystemEntity f) {
      var path = f.path;
      var match = new RegExp(r'[/\\]([^/\\]+)$').firstMatch(path);
      if (match == null || match.group(1) == null) {
        return path;
      }
      return match.group(1);
  }
  
}



class DirectoryResource extends FileEntityResource<FileSystemEntity>
    implements ResourceListable<FileEntityResource> {
  final Directory referencedDirectory;

  DirectoryResource(Directory dir) :
    referencedDirectory = dir,
    super(dir);

  DirectoryResource.fromLink(Link link) :
    referencedDirectory = new Directory(link.resolveSymbolicLinksSync()),
    super(link);

  @override
  bool get isDirectory => true;

  @override
  List<FileEntityResource> list() {
    if (! exists) {
      return <FileEntityResource>[];
    }
    return new List<FileEntityResource>.from(
        referencedDirectory.listSync(recursive: false, followLinks: true)
            .map((f) => fileSystemEntityToResource(f)));
  }

  @override
  FileEntityResource child(String name) {
    return filenameToResource(fullName + '/' + name);
  }

  @override
  bool contains(Resource r) {
    if (r == this) {
      return true;
    }
    return list().any((kid) => kid.contains(r));
  }

}



class FileResource extends FileEntityResource<FileSystemEntity> {
  final File referencedFile;

  FileResource(File f) :
    referencedFile = f,
    super(f);

  FileResource.fromLink(Link link) :
    referencedFile = new File(link.resolveSymbolicLinksSync()),
    super(link);

  @override
  bool get isDirectory => false;

  List<int> readAsBytes() {
    return referencedFile.readAsBytesSync();
  }

  String readAsString({ Encoding encoding: null }) {
    if (encoding == null) {
      encoding = SYSTEM_ENCODING;
    }
    return referencedFile.readAsStringSync(encoding: encoding);
  }

  void writeBytes(List<int> data) {
    referencedFile.writeAsBytesSync(data);
  }

  void writeString(String data, { Encoding encoding: null }) {
    if (encoding == null) {
      encoding = SYSTEM_ENCODING;
    }
    referencedFile.writeAsStringSync(data, encoding: encoding);
  }
}


/**
 * Transforms a list of filenames into a resource collection.  This will
 * not perform a deep scan of directories.  If the optional `include`
 * function is not provided, then all entries from the list of filenames
 * will be added, otherwise the `include` function will be called to test if
 * each should be included.
 */
ResourceCollection filenamesAsCollection(List<String> filenames,
    { bool include(FileEntityResource resource): null }) {
  var resources = <Resource>[];
  for (var name in filenames) {
    resources.add(filenameToResource(name));
  }
  return new SimpleResourceCollection(resources);
}



FileEntityResource fileSystemEntityToResource(FileSystemEntity f) {
  if (f == null) {
    return null;
  }
  if (f is Directory) {
    return new DirectoryResource(f);
  }
  if (f is File) {
    return new FileResource(f);
  }
  if (f is Link) {
    var stripped = f.path.trim();
    Link link = f;
    try {
      String path = link.resolveSymbolicLinksSync();
      if (FileSystemEntity.isDirectorySync(path)) {
        return new DirectoryResource.fromLink(link);
      }
      return new FileResource.fromLink(link);
    } on FileSystemException {
      // File does not exist
      if (stripped.endsWith('/') || stripped.endsWith('\\')) {
        return new DirectoryResource.fromLink(link);
      }
      return new FileResource.fromLink(link);
    }
  }
  throw new BuildSetupException("unexpected file system object: " +
    f.toString());
}



/**
 * Inspect the file name, and attempt to assign it to a [Resource], as either
 * a [FileResource] or a [DirectoryResource].  If the file does not exist,
 * then it is assumed to be a [FileResource].  If the file is actually a link,
 * it will be inspected to see if it points to a directory or file.
 */
FileEntityResource filenameToResource(String filename) {
  if (filename == null) {
    return null;
  }
  var stripped = filename.trim();
  if (stripped.length <= 0) {
    return null;
  }
  FileSystemEntityType type = FileSystemEntity.typeSync(stripped);
  if (type == FileSystemEntityType.FILE) {
    return new FileResource(new File(stripped));
  }
  if (type == FileSystemEntityType.DIRECTORY) {
    return new DirectoryResource(new Directory(stripped));
  }
  if (type == FileSystemEntityType.LINK) {
    Link link = new Link(stripped);
    try {
      String path = link.resolveSymbolicLinksSync();
      if (FileSystemEntity.isDirectorySync(path)) {
        return new DirectoryResource.fromLink(link);
      }
      return new FileResource.fromLink(link);
    } on FileSystemException {
      // File does not exist
      if (stripped.endsWith('/') || stripped.endsWith('\\')) {
        return new DirectoryResource.fromLink(link);
      }
      return new FileResource.fromLink(link);
    }
  }
  if (type == FileSystemEntityType.NOT_FOUND) {
    if (stripped.endsWith('/') || stripped.endsWith('\\')) {
      return new DirectoryResource(new Directory(stripped));
    }
    return new FileResource(new File(stripped));
  }
  throw new BuildSetupException("unexpected file system type: " +
    type.toString());
}




DirectoryResource filenameAsDir(DirectoryResource reldir, String name) {
  var ret = filenameToResource(reldir.fullName + "/" + name + "/");
  if (! (ret is DirectoryResource)) {
    throw new BuildSetupException(name + " is not a directory");
  }
  return ret;
}

