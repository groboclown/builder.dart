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

/**
 * Generic definition of a read/write resource.
 */
abstract class Resource<T extends ResourceListable> {

  String get name;

  String get fullName;

  bool get readable;

  bool get writable;

  bool get exists;

  bool get isLink;

  bool get isDirectory;

  T get parent;

  // default implementation
  bool delete(bool recursive) {
    throw new Exception("delete not supported on " + name);
  }

  // default implementation
  List<int> readAsBytes() {
    throw new Exception("readAsBytes not supported on " + name);
  }

  // default implementation
  String readAsString({ Encoding encoding: null }) {
    throw new Exception("readAsString not supported on " + name);
  }

  // default implementation
  void writeBytes(List<int> data) {
    throw new Exception("writeAsBytes not supported on " + name);
  }

  // default implementation
  void writeString(String data, { Encoding encoding: null }) {
    throw new Exception("writeAsString not supported on " + name);
  }


  bool operator ==(Resource t) {
    if (t == null) {
      return false;
    }
    return fullName == t.fullName;
  }
}


// Mixin class
abstract class ResourceListable<T extends Resource> {
  List<T> list();
}


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

}




class ResourceSet extends ResourceCollection {
  final List<ResourceCollection> _children = <ResourceCollection>[];

  ResourceSet();

  ResourceSet.from(List<ResourceCollection> rc) {
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
      ret.addAll(rc.entries());
    }
  }

}


typedef bool ResourceTest(Resource r);

class ListableResourceColection extends AbstractResourceCollection {
  final ResourceListable res;
  final ResourceTest resourceTest;

  ListableResourceColection(this.res,
    [ this.resourceTest = null ]);

  List<Resource> findResources() {
    var ret = res.list();
    if (resourceTest != null) {
      ret = ret.where(resourceTest);
    }
    return ret;
  }

}



// ===========================================================================
// File system implementation


abstract class FileEntityResource<T extends FileSystemEntity>
    extends Resource<DirectoryResource> {

  final T entity;

  FileEntityResource(this.entity);

  @override
  String get name {
    var path = fullName;
    for (var m in new RegExp(r'[/\\]([^/\\]+)$').allMatches(path)) {
      return m;
    }
    return path;
  }

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


}



class DirectoryResource extends FileEntityResource<FileSystemEntity>
    with ResourceListable<FileEntityResource> {
  final Directory referencedDirectory;

  DirectoryResource(Directory dir) :
    referencedDirectory = dir,
    super(dir);

  DirectoryResource.fromLink(Link link) :
    referencedDirectory = new Directory(link.resolveSymbolicLinksSync()),
    super(link);

  @override
  bool get isDirectory => true;

  List<FileEntityResource> list() {
    return referencedDirectory.listSync(recursive: false, followLinks: true)
      .map((f) => filenameToResource(f));
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


/**
 * Inspect the file name, and attempt to assign it to a [Resource], as either
 * a [FileResource] or a [DirectoryResource].  If the file does not exist,
 * then it is assumed to be a [FileResource].  If the file is actually a link,
 * it will be inspected to see if it points to a directory or file.
 */
FileEntityResource filenameToResource(String filename) {
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
  throw new Exception("unexpected file system type: " + type.toString());
}

