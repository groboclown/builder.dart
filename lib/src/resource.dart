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
 * Handles file and other resources used by the build in an abstract way.  All
 * new [Resource] objects use the [GLOBAL_CONTEXT] instance, unless it is
 * explicitly set at creation time.
 */

import 'dart:io';
import 'dart:collection';
import 'dart:convert';
import 'dart:async';

import 'package:path/path.dart' as path;

import 'exceptions.dart';

bool CASE_SENSITIVE = true;

/**
 * The default Context used for all new [Resource] objects.
 */
path.Context GLOBAL_CONTEXT = new path.Context();


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
   * The name of the resource as passed into the resource, including parent
   * information, but not including the [path.Context].
   */
  String get relname;

  /**
   * The absolute location of the resource, using the [path.Context] information.
   * This will throw a [NoContextException]
   */
  String get absolute;

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
   * The [path.Context] for this [Resource].
   */
  path.Context get context;

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
   * Returns `true` if this [Resource] should be readable.  Issues may arrise
   * from reading such as failure to connect to the resource.
   *
   * For [ResourceListable], it should return `true` if child
   * [ResourceStreamable] can be generally assumed to be readable.
   *
   * For [ResourceStreamable], it returns `true` if the [#readAsBytes()],
   * [#readAsString()], and [#openWrite()] calls are supported by this
   * [Resource].
   */
  bool get readable;


  /**
   * Returns `true` if this [Resource] should be readable.  Issues may arrise
   * from reading such as failure to connect to the resource.
   *
   * For [ResourceListable], it should return `true` if child
   * [ResourceStreamable] can be generally assumed to be readable.
   *
   * For [ResourceStreamable], it returns `true` if the [#writeAsBytes()],
   * [#writeAsString()], and [#openWrite()] calls are
   * supported by this [Resource].
   */
  bool get writable;


/**
   * Checks if this [Resource] represents the exact same [Resource] as `t`.
   */
  @override
  bool operator ==(Resource t) {
    if (t == null) {
      return false;
    }
    return relname == t.relname;
  }
  
  @override
  String toString() {
    return relname;
  }
}



/**
 * A [Resource] which can be read or written.
 */
abstract class ResourceStreamable<T extends ResourceListable> extends Resource<T> {


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
  void writeAsBytes(List<int> data) {
    throw new Exception("writeAsBytes not supported on " + name);
  }


  /**
   * Write the character `data` to this [Resource], using `encoding`
   * to encode the characters as binary data (defaults to the system encoding).
   * If [#writable] is `false`, then this will throw an [Exception].
   */
  // default implementation
  void writeAsString(String data, { Encoding encoding: null }) {
    throw new Exception("writeAsString not supported on " + name);
  }


  /**
   * Opens the [Resource] for asynchronous write access.  Users of this method
   * must close the returned [IOSync] .
   *
   * If the mode is `WRITE` or `APPEND`, and the [writable] property returns
   * `false`, then this will throw an [Exception].  For the `APPEND`
   * file mode, the [readable] attribute must also be `true` or an
   * [Exception] is thrown.
   */
  // default implementation
  IOSink openWrite({ FileMode mode: FileMode.WRITE,
      Encoding encoding: UTF8 }) {
    throw new Exception("openWrite not supported on " + name);
  }


  /**
   * Opens the [Resource] for read in a new independent stream.
   * Users of this method must close the stream in order to free the system
   * resources.
   *
   * If [startPos] is specified, then the read will start at that byte
   * offset, otherwise it will begin at the start of the file (0).
   *
   * If [endPos] is specified, then the read will stop at that byte offset
   * in the file (irrespective of the [startPos]).
   *
   * If the [readable] property returns
   * `false`, then this will throw an [Exception].
   */
  // default implementation
  Stream<List<int>> openRead([ int startPos, int endPos ]) {
    throw new Exception("open not supported on " + name);
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


  /**
   * Returns the path of the [child] relative to this listable.  If the
   * [child]] is not actually a child, then this will return `null`.
   */
  String relativeChildName(Resource child);
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


class DirectoryCollection extends ListableResourceCollection {
  ResourceTest recurseTest;
  bool addDirectories;
  
  
  factory DirectoryCollection.files(ResourceListable res,
      ResourceTest fileTest) {
    //ResourceTest resTest = (f) {
    //    print("Checking " + f.name + ": directory? " + f.isDirectory.toString() + "; fileTest? " + fileTest(f).toString());
    //    if (f.isDirectory && ! (f is DirectoryResource)) { print(" - but it's not a DirectoryResource!"); }
    //    return fileTest(f);
    //};
    ResourceTest recurseTest = DEFAULT_IGNORE_TEST;
    return new DirectoryCollection(res, fileTest, recurseTest);
  }


  factory DirectoryCollection.everything(ResourceListable root) {
    return new DirectoryCollection(root, null, null, true);
  }
  
  
  /**
   * `resourceTest` is for deciding whether a [Resource] should be added to
   * the output or not.  `recurseTest` is for deciding whether a
   * [ResourceListable] should have its contents examined.
   */
  DirectoryCollection(ResourceListable res, [ ResourceTest resourceTest,
    ResourceTest recurseTest, bool addDirectories = false ]) :
    this.recurseTest = recurseTest, this.addDirectories = addDirectories,
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
    if (addDirectories) {
      ret.add(listable);
    }
  }
  
}





// ===========================================================================
// File system implementation


abstract class FileEntityResource<T extends FileSystemEntity>
    extends Resource<DirectoryResource> {

  final T entity;
  final String _relname;
  final path.Context _context;

  FileEntityResource.inner(this.entity, this._context, this._relname);

  factory FileEntityResource.fromEntity(FileSystemEntity res,
      { path.Context context: null }) {
    if (context == null) {
      context = GLOBAL_CONTEXT;
    }
    var relname = context.relative(res.path);
    var notFoundHint = (res is Directory ? 'dir' :
      res is Link ? null : 'file' );
    return new FileEntityResource(relname, context: context,
      notFoundHint: notFoundHint);
  }




  /**
   *
   * [notFoundHint] is used if the file entry does not currently exist.
   * It can be `dir` or `file` or `null`.  If `null`, then the constructor
   * checks if the [relname] ends with a separator character (`/` or `\`)
   * to determine if it should be considered a directory or file.
   */
  factory FileEntityResource(String relname,
      { path.Context context: null, String notFoundHint: null }) {
    if (relname == null) {
      throw new BuildSetupException("null relname");
    }
    if (context == null) {
      context = GLOBAL_CONTEXT;
    }
    if (context.style == path.Style.url) {
      throw new BuildSetupException("invalid context style for File: " +
        context.style.toString());
    }
    var link = null;
    var fullname = context.absolute(relname);
    //print("relname: [" + relname.toString() + "]; fullname: [" + fullname + "]");
    var stat;
    try {
      stat = FileStat.statSync(fullname);
    } catch (e, s) {
      // This is a work-around for http://code.google.com/p/dart/issues/detail?id=16558
      // FIXME that bug is fixed, so when Dart v1.1.4 is released, this try/catch
      // block can be removed.
      //print(s.toString());
    }
    if (stat != null && stat.type == FileSystemEntityType.LINK) {
      try {
        link = new Link(fullname);
        stat = FileStat.statSync(link.resolveSymbolicLinksSync());
      } on FileSystemException catch(e) {
        // link does not point to a real file
        stat = null;
      }
    }
    if (stat == null || stat.type == null ||
        stat.type == FileSystemEntityType.NOT_FOUND) {
      if (notFoundHint == 'dir') {
        if (link != null) {
          return new DirectoryResource.fromLink(link, context, relname);
        } else {
          return new DirectoryResource(new Directory(fullname),
            context, relname);
        }
      } else if (notFoundHint == 'file') {
        if (link != null) {
          return new FileResource.fromLink(link, context, relname);
        } else {
          return new FileResource(new File(fullname),
            context, relname);
        }
      } else if (relname.endsWith('/') || relname.endsWith('\\') ||
          relname.endsWith(context.separator)) {
        if (link != null) {
          return new DirectoryResource.fromLink(link, context, relname);
        } else {
          return new DirectoryResource(new Directory(fullname),
            context, relname);
        }
      } else {
        if (link != null) {
          return new FileResource.fromLink(link, context, relname);
        } else {
          return new FileResource(new File(fullname),
            context, relname);
        }
      }
    } else if (stat.type == FileSystemEntityType.DIRECTORY) {
      if (link != null) {
        return new DirectoryResource.fromLink(link, context, relname);
      } else {
        return new DirectoryResource(new Directory(fullname),
          context, relname);
      }
    } else if (stat.type == FileSystemEntityType.FILE) {
      if (link != null) {
        return new FileResource.fromLink(link, context, relname);
      } else {
        return new FileResource(new File(fullname),
          context, relname);
      }
    } else {
      throw new BuildSetupException("unknown stat type '" +
        stat.type.toString() + "' for '" + relname + "'");
    }
  }





  @override
  String get name => context.basename(relname);

  @override
  String get relname => _relname;

  @override
  String get absolute => _context.absolute(relname);

  @override
  path.Context get context => _context;

  @override
  // This looks related to Dart issue 16558
  //bool get exists => entity.existsSync();
  bool get exists {
    try {
      return entity.existsSync();
    } catch (e) {
      return false;
    }
  }


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
  bool get isLink => entity is Link;

  @override
  DirectoryResource get parent =>
      new FileEntityResource.fromEntity(entity.parent);

  @override
  bool delete(bool recursive) {
    try {
      entity.deleteSync(recursive: recursive);
      return true;
    } catch(e) {
      return false;
    }
  }

}



class DirectoryResource extends FileEntityResource<FileSystemEntity>
    implements ResourceListable<FileEntityResource> {
  final Directory referencedDirectory;


  factory DirectoryResource.named(String relname,
      { path.Context context: null }) {
    return new FileEntityResource(relname, context: context,
      notFoundHint: 'dir') as DirectoryResource;
  }

  DirectoryResource(Directory dir, path.Context context, String relname) :
    referencedDirectory = dir,
    super.inner(dir, context, relname);

  DirectoryResource.fromLink(Link link, path.Context context, String relname) :
    referencedDirectory = new Directory(link.resolveSymbolicLinksSync()),
    super.inner(link, context, relname);

  @override
  bool get isDirectory => true;

  @override
  List<FileEntityResource> list() {
    if (! exists) {
      return <FileEntityResource>[];
    }
    return new List<FileEntityResource>.from(
        referencedDirectory.listSync(recursive: false, followLinks: true)
            .map((f) => new FileEntityResource.fromEntity(f,
                context: this.context)));
  }

  @override
  FileEntityResource child(String name, [ String notFoundHint ]) {
    return new FileEntityResource(relname + context.separator + name,
      context: this.context, notFoundHint: notFoundHint);
  }

  @override
  bool contains(Resource r) {
    if (r == this) {
      return true;
    }
    return context.isWithin(absolute, r.absolute);
  }


  @override
  String relativeChildName(Resource child) {
    if (context.isWithin(absolute, child.absolute)) {
      return context.relative(child.absolute, from: absolute);
    }
    return null;
  }


  /**
   * Return this directory resource as a collection.
   */
  ResourceCollection asCollection({ ResourceTest resourceTest,
      ResourceTest recurseTest, bool addDirectories: false }) {
    return new DirectoryCollection(this,
      resourceTest, recurseTest, addDirectories);
  }


  /**
   * Return this directory resource as a collection of every file in the
   * directory.
   */
  ResourceCollection everything() {
    return new DirectoryCollection.everything(this);
  }

}


/**
 * A file system file.
 */
class FileResource extends FileEntityResource<FileSystemEntity>
    implements ResourceStreamable<DirectoryResource> {
  final File referencedFile;


  factory FileResource.named(String relname,
      { path.Context context: null }) {
    return new FileEntityResource(relname, context: context,
      notFoundHint: 'file') as FileResource;
  }


  FileResource(File f, path.Context context, String relname) :
    referencedFile = f,
    super.inner(f, context, relname);

  FileResource.fromLink(Link link, path.Context context, String relname) :
    referencedFile = new File(link.resolveSymbolicLinksSync()),
    super.inner(link, context, relname);

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

  void writeAsBytes(List<int> data) {
    if (! referencedFile.parent.existsSync()) {
      referencedFile.parent.createSync(recursive: true);
    }
    referencedFile.writeAsBytesSync(data);
  }

  void writeAsString(String data, { Encoding encoding: null }) {
    if (encoding == null) {
      encoding = SYSTEM_ENCODING;
    }
    if (! referencedFile.parent.existsSync()) {
      referencedFile.parent.createSync(recursive: true);
    }
    referencedFile.writeAsStringSync(data, encoding: encoding, flush: true);
  }

  IOSink openWrite({ FileMode mode: FileMode.WRITE,
                   Encoding encoding: UTF8 }) {
    if (! referencedFile.parent.existsSync()) {
      referencedFile.parent.createSync(recursive: true);
    }
    return referencedFile.openWrite(mode: mode, encoding: encoding);
  }

  Stream<List<int>> openRead([ int startPos, int endPos ]) {
    return referencedFile.openRead(startPos, endPos);
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
    var res = new FileEntityResource(name);
    if (include == null || include(res)) {
      resources.add(res);
    }
  }
  return new SimpleResourceCollection(resources);
}

