Declarative Style Builds
========================

Declarative builds define all the tasks that need to be run, with a few light suggestions about the order in which they should be run (where necessary), and the build tool figures out the correct build order at runtime.  Declarative builds tend to be faster than [procedural](procedural.md), because the engine can optimize for the smallest amount of work based on the discovered changes in the build files.
