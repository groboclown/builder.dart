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
import 'dart:io';

import 'package:ansicolor/ansicolor.dart';

import 'targetmethod.dart';
import 'resource.dart';




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

  void exception(var exception, [ StackTrace stackTrace ]) {
    _logger.output(_target, new LogExceptionMessage(
        tool: _target.name, message: exception == null ? "exception" :
          exception.toString(), exception: exception, stackTrace: stackTrace));
  }

  void fileInfo({ String tool: null,
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null }) {
    _logger.output(_target, new LogResourceMessage(
        tool: tool == null ? _target.name : tool,
        level: INFO, category: category, id: id, file: file, line: line,
        charStart: charStart, charEnd: charEnd, message: message));
  }

  void fileWarn({ String tool: null,
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null }) {
    _logger.output(_target, new LogResourceMessage(
        tool: tool == null ? _target.name : tool,
        level: WARNING, category: category, id: id, file: file, line: line,
        charStart: charStart, charEnd: charEnd, message: message));
  }

  void fileError({ String tool: null,
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null }) {
    _logger.output(_target, new LogResourceMessage(
        tool: tool == null ? _target.name : tool,
        level: ERROR, category: category, id: id, file: file, line: line,
        charStart: charStart, charEnd: charEnd, message: message));
  }

  void fileException({
      String tool: null, String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null, var exception, StackTrace stackTrace: null }) {
    _logger.output(_target, new LogExceptionMessage(
        tool: tool == null ? _target.name : tool,
        message: exception == null ? "exception" :
        exception.toString(), exception: exception, stackTrace: stackTrace,
        category: category, id: id, file: file, line: line,
        charStart: charStart, charEnd: charEnd));
  }

  void message(LogMessage msg) {
    _logger.output(_target, msg);
  }

}


const String WARNING = "warning";
const String ERROR = "error";
const String INFO = "info";
const String MAPPING = "mapping";
const String DEBUG = "debug";


/**
 * Generic message to log.
 */
class LogMessage {
  String level; // WARNING or ERROR or INFO
  String message;
  final String message_type;

  factory LogMessage({ String level: INFO, String message: null }) {
    return new LogMessage._("general", level, message);
  }

  LogMessage._(this.message_type, this.level, this.message);


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


  factory LogMessage.exception({ String level: ERROR, String tool: "internal",
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null, var exception: null,
      StackTrace stackTrace: null }) {
    return new LogExceptionMessage(level: level, tool: tool, category: category,
      id: id, file: file, line: line, charStart: charStart, charEnd: charEnd,
      message: message, exception: exception, stackTrace: stackTrace);
  }


  factory LogMessage.mapping({ String tool: "internal",
      Resource from: null, Resource to: null }) {
    return new LogMappingMessage(tool: tool, from: from, to: to);
  }


  factory LogMessage.fromJson(jsonValue) {
    return new JsonLogMessage(jsonValue);
  }





  Map<String, dynamic> createParams() {
    return <String, dynamic>{
      "message": message
    };
  }


  Map<String, dynamic> toJson() {
    return { "method": level, "message_type": message_type,
        "params": createParams() };
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
      String message: null, String message_type: "tool" }) :
      this.tool = tool,
      this.category = category,
      this.id = id,
      super._(message_type, level, message);

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
      String message: null, String message_type: "resource" }) :
      this.file = file,
      this.line = line,
      this.charStart = charStart,
      this.charEnd = charEnd,
      super(level: level, tool: tool, category: category, id: id,
        message: message, message_type: message_type);

  @override
  Map<String, dynamic> createParams() {
    var params = super.createParams();
    params.addAll(<String, dynamic>{
        "file": file.relname,
        "line": line,
        "charStart": charStart,
        "charEnd": charEnd
    });
    return params;
  }

}



class LogExceptionMessage extends LogResourceMessage {
  var exception;
  StackTrace stackTrace;



  LogExceptionMessage({ String level: ERROR, String tool: "internal",
      String category: "INTERNAL", String id: "UNKNOWN",
      Resource file: null, int line: 1, int charStart: 0, int charEnd: 0,
      String message: null, String message_type: "exception",
      var exception: null, StackTrace stackTrace: null }) :
    this.exception = exception,
    this.stackTrace = stackTrace,
    super(level: level, tool: tool, category: category, id: id,
      message: message, message_type: message_type, file: file,
      line: line, charStart: charStart, charEnd: charEnd);

  @override
  Map<String, dynamic> createParams() {
    var params = super.createParams();
    params.addAll(<String, dynamic>{
        "exception": exception == null ? null : exception.toString(),
        "stackTrace": stackTrace == null ? null : stackTrace.toString()
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
      Resource from: null, Resource to: null,
      message_type: "mapping" }) :
      this.tool = tool,
      this.from = from,
      this.to = to,
      super._(message_type, MAPPING, "mapped `" + from.toString() +
        "` to `" + to.toString() + "`");

  @override
  Map<String, dynamic> createParams() {
    var params = super.createParams();
    params.addAll(<String, dynamic>{
        "tool": tool,
        "from": from.relname,
        "to": to.relname
    });
    return params;
  }

}


class JsonLogMessage extends LogMessage {
  final Map<String, dynamic> params = <String, dynamic>{};

  JsonLogMessage(jsonMessage) :
      super._(jsonMessage['message_type'], jsonMessage['method'],
        jsonMessage['params']['message']) {

    jsonMessage['params'].forEach((k, v) {
      if (k != 'message') {
        params[k] = v;
      }
    });
  }

  @override
  Map<String, dynamic> createParams() {
    var p = super.createParams();
    p.addAll(params);
    return p;
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
    var parms = message.createParams();

    // The 'file' part is required by the Dart editor.
    if (! parms.containsKey("file")) {
      parms["file"] = "";
    }
    print('[{"method":"' + message.level + '","params":' +
        JSON.encode(parms) + '}]');
  }
}



class CmdLogger extends AbstractLogger {
  final AnsiPen pen;

  CmdLogger([ bool enableColor = null ]) : pen = new AnsiPen() {
    if (enableColor == false || (enableColor == null && Platform.isWindows)) {
      // windows CMD by default doesn't support ansi colors
      color_disabled = true;
    }
  }


  @override
  void output(TargetMethod tm, LogMessage message) {
    var params = message.createParams();

    var buff = new StringBuffer();
    if (tm != null) {
      if (message.level == ERROR) {
        pen
          ..white(bold: true)
          ..red(bg: true);
      } else if (message.level == WARNING) {
        pen
          ..reset()
          ..magenta(bold: true);
      } else {
        pen
          ..reset()
          ..white(bold: true);
      }
      buff.write(pen(message.level.substring(0,
          message.level.length > 4 ? 4 : message.level.length)
            .toUpperCase()));
      pen
        ..reset()
        ..green(bold: true);
      buff
        ..write(" [")
        ..write(pen((tm == null ? "???" : tm.name)))
        ..write("] ");
    }
    buff..write(message.message);
    print(buff);

    var parms = message.createParams();
    if (message.message_type == 'resource' &&
        parms['charStart'] != 0 &&
        parms['charEnd'] != 0) {

      // TODO load the file and show the problem!

      pen
        ..reset()
        ..yellow();
      buff.clear();
      buff..write("...  in ")
          ..write(pen(parms['file']))
          ..write(", line ");
      pen
        ..reset()
        ..cyan();
      buff
        ..write(pen(parms['line'].toString()))
        ..write(", col ")
        ..write(pen((parms['charStart'] + 1).toString() + "-" +
          (parms['charEnd'] + 1).toString()));
      print(buff);
    }
  }
}
