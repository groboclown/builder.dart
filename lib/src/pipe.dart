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
 * Defines how [Resource]s map from one source to a destination.
 */

library builder.src.pipe;

import 'resource.dart';



/**
 * Describes how a [BuildTool] connects with the resources.
 */

abstract class Pipe {
  /**
   * All inputs that are required to exist before the [BuildTool] can run.
   * These must be defined before the build runs.
   */
  Iterable<Resource> get requiredInput;

  /**
   * All the input [Resource] that, if they are generated by another build
   * tool, will be run before the [BuildTool].
   */
  Iterable<Resource> get optionalInput;

  /**
   * As many [Resource] that can be anticipated to be generated by the
   * tool.  Where possible, this should be all the precise resources,
   * or, if the tool generates a bunch of files whose name can't be
   * accurately predicted, then at least the directory into which they
   * will be placed.
   *
   * Multiple build tools can output into the same directory.
   */
  Iterable<Resource> get output;

  /**
   * Any input that can be mapped directly to one or more [Resource]
   * should include a direct pipe reference to allow for more efficient
   * building.
   */
  Map<Resource, List<Resource>> get directPipe;

  /**
   * All the output that is not explicitly optional, as based upon the
   * [directPipe] output coming from the optional input.
   */
  Iterable<Resource> get requiredOutput;

/**
   * Match the given input to the corresponding output [Resource]s.  It first
   * uses the [#directPipe] before defaulting to the [#output].  If there
   * were no matches, it returns an empty list.
   */
  Iterable<Resource> matchOutput(Resource input) {
    List<Resource> ret = <Resource>[];
    directPipe.keys
      // Iterable<Resource>
      .where((Resource r) => input.matches(r))
      // Iterable<Resource>
      .map((Resource r) => directPipe[r])
      // Iterable<Iterable<Resource>>
      .forEach((Iterable<Resource> rl) => ret.addAll(rl));
    if (ret.isNotEmpty) {
      return ret;
    }

    if (requiredInput.any((Resource r) => input.matches(r))) {
      return new List<Resource>.from(output);
    }

    if (optionalInput.any((Resource r) => input.matches(r))) {
      return new List<Resource>.from(output);
    }

    return ret;
  }



  factory Pipe.direct(Map<Resource, List<Resource>> direct) {
    return new SimplePipe.direct(direct);
  }


  factory Pipe.single(Resource input, Resource output) {
    return new SimplePipe.single(input, output);
  }


  factory Pipe.list(List<Resource> inputs, List<Resource> outputs) {
    return new SimplePipe.list(inputs, outputs);
  }


  factory Pipe.all({ Iterable<Resource> requiredInput: null,
      Iterable<Resource> optionalInput: null,
      Iterable<Resource> output: null,
      Map<Resource, Iterable<Resource>> directPipe: null }) {
    if (requiredInput == null) {
      requiredInput = <Resource>[];
    }
    if (optionalInput == null) {
      optionalInput = <Resource>[];
    }
    if (directPipe == null) {
      directPipe = <Resource, List<Resource>>{};
    }
    return new SimplePipe.all(requiredInput: requiredInput,
      optionalInput: optionalInput, output: output, directPipe: directPipe);
  }


  Pipe() {
  }
}


class SimplePipe extends Pipe {
  final Set<Resource> _requiredInput = new Set<Resource>();

  final Set<Resource> _optionalInput = new Set<Resource>();

  final Set<Resource> _output = new Set<Resource>();

  final Set<Resource> _requiredOutput = new Set<Resource>();

  final Map<Resource, Iterable<Resource>> _directPipe =
  <Resource, Iterable<Resource>>{
  };

  /**
   * Puts all the direct inputs as required inputs.
   */
  SimplePipe.direct(Map<Resource, Iterable<Resource>> direct) {
    // Ensure we don't have duplicates in the wrong places
    for (var r in direct.keys) {
      _requiredInput.add(r);
      Set<Resource> out = new Set<Resource>.from(direct[r]);
      _directPipe[r] = out;
      _output.addAll(out);
    }
    _requiredOutput.addAll(_output);
  }


  SimplePipe.single(Resource input, Resource output) {
    if (input != null) {
      _requiredInput.add(input);
    }
    if (output != null) {
      _output.add(output);
    }
    if (input != null && output != null) {
      _directPipe[input] = [ output ];
    }
    _requiredOutput.addAll(_output);
  }


  SimplePipe.list(Iterable<Resource> inputs, Iterable<Resource> outputs) {
    if (inputs != null) {
      _requiredInput.addAll(inputs);
    }
    if (outputs != null) {
      _output.addAll(outputs);
    }
    _requiredOutput.addAll(_output);
  }


  SimplePipe.all({ Iterable<Resource> requiredInput: null,
      Iterable<Resource> optionalInput: null,
      Iterable<Resource> output: null,
      Map<Resource, Iterable<Resource>> directPipe: null }) {
    if (requiredInput != null) {
      _requiredInput.addAll(new Set<Resource>.from(requiredInput));
    }
    if (optionalInput != null) {
      _optionalInput.addAll(new Set<Resource>.from(optionalInput));
    }

    var out = new Set<Resource>();
    if (output != null) {
      out.addAll(output);
      _requiredOutput.addAll(output);
    }

    // populate the required output with all output that is not explicitly
    // optional; do this by adding all output, then removing all optional
    // inputs' outputs, then add in all required inputs' outputs.
    if (directPipe != null) {
      for (Resource r in directPipe.keys) {
        if (!_requiredInput.contains(r) && !_optionalInput.contains(r)) {
          _optionalInput.add(r);
          _requiredOutput.removeAll(directPipe[r]);
        }
        _directPipe[r] = new Set<Resource>.from(directPipe[r]);
        out.addAll(_directPipe[r]);
      }
    }
    _output.addAll(out);
    _requiredInput.forEach((r) {
      if (_directPipe.containsKey(r)) {
        _requiredOutput.addAll(_directPipe[r]);
      }
    });
  }


  @override
  Iterable<Resource> get requiredInput => _requiredInput;

  @override
  Iterable<Resource> get optionalInput => _optionalInput;

  @override
  Iterable<Resource> get output => _output;

  /**
   * All the output that is not explicitly marked as optional.
   */
  @override
  Iterable<Resource> get requiredOutput => _requiredOutput;

  @override
  Map<Resource, Iterable<Resource>> get directPipe => _directPipe;
}


