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

/**
 * Handles the dirty file detection for resources.  If a resource has been
 * changed since the previous run of a target, then it is marked as "dirty",
 * and will be returned.  If it hasn't changed, then the target won't use
 * it for processing.
 */
library builder.src.dirty;

import 'resource.dart';


class DirtyDepot {
  final DirectoryResource dirtyDir;

  DirtyDepot.fromTempDir(this.dirtyDir);

  /**
   * Clean out all files from the depot, so that everything looks like a
   * dirty file.
   */
  void clean() {
    // FIXME
  }

  /**
   * Returns true if a file is not known to the depot, or is different than
   * the version known to the depot.
   */
  bool isDirty(ResourceStreamable res) {
    // FIXME
    return true;
  }

  Iterable<Resource> asDirtyResources(Iterable<Resource> resources) {
    // FIXME
    return resources;
  }


}


class DirtyResourceCollection implements ResourceCollection {
  // FIXME
  @override
  Iterable<Resource> entries() {
    // TODO: implement entries
    return null;
  }
}
