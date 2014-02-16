Procedural Builds
=================

Procedural builds differ from declarative builds in that they define, in
broad strokes, the build dependency tree, while leaving the details for the
actual execution to the build script itself, rather than relying upon other
build tools to perform the work.

Procedural build files tend to have fewer targets than their declarative
counterparts, and define the explicit steps of the build inside each target.
