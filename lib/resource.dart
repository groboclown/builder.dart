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

import 'dart:io';
import 'dart:convert';

/**
 * Handles Streams in an abstract way, and manages lists of Streams.
 */

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

  SimpleResourceCollection(this._entries);

  SimpleResourceCollection.single(Resource entry) :
      _entries = <Resource>[ entry ];

  @override
  List<Resource> entries() => this._entries;
}



abstract class AbstractResourceCollection extends ResourceCollection {
  List<Resource> _entries;

  @override
  List<Resource> entries() {
    if (_entries == null) {
      _entries = findResources();
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


class ListableResourceColection extends AbstractResourceCollection {
  final ResourceListable res;

  ListableResourceColection(this.res);

  List<Resource> findResources() {
    return res.list();
  }

}



// ===========================================================================
// File system implementation


class FileEntityResource<T extends FileSystemEntity>
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
  bool get isDirectory => entity is Directory || (entity is Link && _isLinkDir(entity));

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


  bool _isLinkDir(Link f) {
    try {
      String path = f.resolveSymbolicLinksSync();
      return FileSystemEntity.isDirectorySync(path);
    } on FileSystemException {
      // does not point to a real object
      return false;
    }
  }
}



class DirectoryResource extends FileEntityResource<FileSystemEntity>
    with ResourceListable<FileEntityResource> {
  DirectoryResource(FileSystemEntity dir) : super(dir);

  List<FileEntityResource> list() {
    return _asDir().listSync(recursive: false, followLinks: true).map((f) =>
      f is Directory || (f is Link && _isLinkDir(f))
        ? new DirectoryResource(f)
        : new FileResource(f));
  }


  Directory _asDir() {
    if (entity is Directory) {
      return entity as Directory;
    }
    var e = entity as Link;
    return new Directory(e.resolveSymbolicLinksSync());
  }


}



class FileResource extends FileEntityResource<FileSystemEntity> {
  FileResource(FileSystemEntity f) : super(f);

  List<int> readAsBytes() {
    return _asFile().readAsBytesSync();
  }

  String readAsString({ Encoding encoding: null }) {
    if (encoding == null) {
      encoding = SYSTEM_ENCODING;
    }
    return _asFile().readAsStringSync(encoding: encoding);
  }

  void writeBytes(List<int> data) {
    _asFile().writeAsBytesSync(data);
  }

  void writeString(String data, { Encoding encoding: null }) {
    if (encoding == null) {
      encoding = SYSTEM_ENCODING;
    }
    _asFile().writeAsStringSync(data, encoding: encoding);
  }

  File _asFile() {
    if (entity is File) {
      return entity as File;
    }
    var e = entity as Link;
    return new File(e.resolveSymbolicLinksSync());
  }

}




