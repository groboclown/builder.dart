Procedural Style Builds
=======================

Procedural builds differ from [declarative builds](declarative.md) in that they
define the coarse-grained build dependency tree, while leaving the details
for the actual execution to the build script itself, rather than relying upon
other build tools to attempt to figure it out.

Procedural build files tend to have fewer targets than their declarative
counterparts, and define the explicit steps of the build inside each target.

