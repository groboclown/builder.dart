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


library builder.logger;

import 'dart:convert';

import 'target.dart';
import '../resource.dart';


class Logger {
  final TargetMethod _target;
  final AbstractLogger _logger;

  Logger(this._target, this._logger);

  void debug(String message) {
    // for now, nothing is done.  Eventually a
    // "log level" will be added.
  }
  
  void info(String message) {
    _logger.output(_target, new LogToolMessage(
      level: INFO, tool: _target.name, message: message));
  }

  void warn(String message) {
    _logger.output(_target, new LogToolMessage(
        level: WARNING, tool: _target.name, message: message));
  }

  void error(String message) {
    _logger.output(_target, new LogToolMessage(
        level: ERROR, tool: _target.name, message: message));
  }

  void fileInfo({ String tool: "internal",
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null }) {
    _logger.output(_target, new LogResourceMessage(
        level: INFO, category: category, id: id, file: file, line: line,
        charStart: charStart, charEnd: charEnd, message: message));
  }

  void fileWarn({ String tool: "internal",
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null }) {
    _logger.output(_target, new LogResourceMessage(
        level: WARNING, category: category, id: id, file: file, line: line,
        charStart: charStart, charEnd: charEnd, message: message));
  }

  void fileError({ String tool: "internal",
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null }) {
    _logger.output(_target, new LogResourceMessage(
        level: ERROR, category: category, id: id, file: file, line: line,
        charStart: charStart, charEnd: charEnd, message: message));
  }

  void message(LogMessage msg) {
    _logger.output(_target, msg);
  }

}


const String WARNING = "warning";
const String ERROR = "error";
const String INFO = "info";
const String MAPPING = "mapping";


/**
 * Generic message to log.
 */
class LogMessage {
  String level; // WARNING or ERROR or INFO
  String message;

  LogMessage({ String level: INFO, String message: null }) :
      this.level = level,
      this.message = message;


  factory LogMessage.tool({ String level: INFO, String tool: "internal",
      String category: "INTERNAL", String id: "UNKNOWN",
      String message: null }) {
    return new LogToolMessage(level: level, tool: tool, category: category,
      id: id, message: message);
  }


  factory LogMessage.resource({ String level: INFO, String tool: "internal",
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null }) {
    return new LogResourceMessage(level: level, tool: tool, category: category,
      id: id, file: file, line: line, charStart: charStart, charEnd: charEnd,
      message: message);
  }


  factory LogMessage.mapping({ String tool: "internal",
      Resource from: null, Resource to: null }) {
    return new LogMappingMessage(tool: tool, from: from, to: to);
  }





  Map<String, dynamic> createParams() {
    return <String, dynamic>{
      "message": message
    };
  }


  Map<String, dynamic> toJson() {
    return { "method": level, "params": createParams };
  }
}


/**
 * Generic message from a tool.
 */
class LogToolMessage extends LogMessage {
  String tool; // the tool that generated the message
  String category; // COMPILE_TIME_ERROR, STATIC_WARNING, ...
  String id; // UNDEFINED_CLASS, UNDEFINED_IDENTIFIER, ...

  LogToolMessage({ String level: INFO, String tool: "internal",
      String category: "INTERNAL", String id: "UNKNOWN",
      String message: null }) :
      this.tool = tool,
      this.category = category,
      this.id = id,
      super(level: level, message: message);

  @override
  Map<String, dynamic> createParams() {
    var params = super.createParams();
    params.addAll(<String, dynamic>{
      "tool": tool,
      "category": category,
      "id": id
    });
    return params;
  }

}


/**
 * A container structure for logging a message about a resource
 */
class LogResourceMessage extends LogToolMessage {
  Resource file;
  int line; // 1 based
  int charStart; // 0 based
  int charEnd; // 0 based

  LogResourceMessage({ String level: INFO, String tool: "internal",
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null }) :
      this.file = file,
      this.line = line,
      this.charStart = charStart,
      this.charEnd = charEnd,
      super(level: level, tool: tool, category: category, id: id, message: message);

  @override
  Map<String, dynamic> createParams() {
    var params = super.createParams();
    params.addAll(<String, dynamic>{
        "file": file.fullName,
        "line": line,
        "charStart": charStart,
        "charEnd": charEnd
    });
    return params;
  }

}


/**
 * Reports on an input resource mapped to an output resource.
 */
class LogMappingMessage extends LogMessage {
  String tool; // the tool that generated the message
  Resource from;
  Resource to;

  LogMappingMessage({ String tool: "internal",
      Resource from: null, Resource to: null }) :
      this.tool = tool,
      this.from = from,
      this.to = to,
      super(level: MAPPING, message: "mapped `" + from.toString() +
        "` to `" + to.toString() + "`");

  @override
  Map<String, dynamic> createParams() {
    var params = super.createParams();
    params.addAll(<String, dynamic>{
        "tool": tool,
        "from": from.fullName,
        "to": to.fullName
    });
    return params;
  }

}







/**
 * Abstract logging method to allow for correct feedback either to the user
 * in the command-line (human readable) or to the Dart Editor (JSON).
 */
abstract class AbstractLogger {
  void output(TargetMethod tm, LogMessage message);
}



class JsonLogger extends AbstractLogger {

  @override
  void output(TargetMethod tm, LogMessage message) {
    print('[{"method":"' + message.level + '","params":' +
        JSON.encode(message.createParams()) + '}]');
  }
}



class CmdLogger extends AbstractLogger {

  @override
  void output(TargetMethod tm, LogMessage message) {
    var params = message.createParams();
    print(message.level.substring(0,
        message.level.length > 4 ? 4 : message.level.length)
      .toUpperCase() + " [" + (tm == null ? "???" : tm.name) + "] " +
        message.message);
    if (message is LogResourceMessage) {
      var rm = message;
      print("   in " + rm.file.fullName + ", line " + rm.line.toString() +
        ", col " + (rm.charStart + 1).toString() + "-" +
        (rm.charEnd + 1).toString());
    }
  }
}
