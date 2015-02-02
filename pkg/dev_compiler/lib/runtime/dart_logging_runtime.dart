library ddc.runtime.dart_logging_runtime;

import 'dart:mirrors' as mirrors;

import 'dart_runtime.dart' as rt;
export 'dart_runtime.dart' show Arity, getArity, type;

import 'package:stack_trace/stack_trace.dart';

// Logging / updating CastRecords for cases that alway pass in Dart and DDC
// is expensive.  They are also less interesting, so filter out by default.
const bool _skipSuccess = true;

class CastRecord {
  final Type runtimeType;
  final Type staticType;
  final bool ddcSuccess;
  final bool dartSuccess;

  CastRecord(
      this.runtimeType, this.staticType, this.ddcSuccess, this.dartSuccess);
}

// Register a handler to process CastRecords.  The default (see below) just
// prints a summary at the end.
typedef void CastRecordHandler(String key, CastRecord record);
CastRecordHandler castRecordHandler = _record;

var _cache = <Type, Map<Type, CastRecord>>{};

Map<Type, CastRecord> _cacheGen() => <Type, CastRecord>{};

void _addToCache(Type runtimeType, Type staticType, CastRecord record) {
  _cache.putIfAbsent(runtimeType, _cacheGen)[staticType] =
    record;
}

CastRecord _lookupInCache(Type runtimeType, Type staticType) {
  var subcache = _cache[runtimeType];
  if (subcache == null) return null;
  return subcache[staticType];
}

var _successCache = <Type, Set<Type>>{};

dynamic cast(dynamic obj, Type staticType, {String key}) {
  var runtimeType = obj.runtimeType;
  // Short-circuit uninteresting cases.
  if (_skipSuccess && _successCache.containsKey(staticType)) {
    if (_successCache[staticType].contains(runtimeType)) {
      return obj;
    }
  }

  if (key == null) {
    // If no key is past in, use the caller's frame as a key.
    final trace = new Trace.current(1);
    final frame = trace.frames.first;
    key = frame.toString();
  }

  CastRecord record = _lookupInCache(runtimeType, staticType);
  if (record == null) {
    bool ddcSuccess = true;
    bool dartSuccess = true;
    // TODO(vsm): Use instanceOf once we settle on nullability.
    try {
      rt.cast(obj, staticType);
    } catch (e) {
      ddcSuccess = false;
    }
    if (obj == null) {
      dartSuccess = true;
    } else {
      // TODO(vsm): We could avoid mirror code by requiring the caller to pass
      // in obj is TypeLiteral as a parameter.  We can't do that once we have a
      // Type object instead.
      final staticMirror = mirrors.reflectType(staticType);
      final instanceMirror = mirrors.reflect(obj);
      final classMirror = instanceMirror.type;
      dartSuccess = classMirror.isSubtypeOf(staticMirror);
    }
    if (_skipSuccess && dartSuccess && ddcSuccess) {
      _successCache.putIfAbsent(staticType, () => new Set<Type>()).add(runtimeType);
      return obj;
    }
    record =
      new CastRecord(runtimeType, staticType, ddcSuccess, dartSuccess);
    _addToCache(runtimeType, staticType, record);
  }
  castRecordHandler(key, record);
  return obj;
}

// The default handler simply records all CastRecords and prints a summary
// at the end.
final _recordMap = new Map<String, List<CastRecord>>();
void _record(String key, CastRecord record) {
  _recordMap.putIfAbsent(key, () => <CastRecord>[]).add(record);
}

String summary({bool clear: true}) {
  final buffer = new StringBuffer();
  _recordMap.forEach((String key, List<CastRecord> records) {
    int success = 0;
    int mismatch = 0;
    int error = 0;
    int failure = 0;
    Type staticType = null;
    var runtimeTypes = new Set<Type>();
    for (var record in records) {
      if (staticType == null) {
        staticType = record.staticType;
      } else {
        // Are these canonicalized?
        // assert(staticType == record.staticType);
      }
      runtimeTypes.add(record.runtimeType);
      if (record.ddcSuccess) {
        if (record.dartSuccess) {
          success++;
        } else {
          error++;
        }
      } else {
        if (record.dartSuccess) {
          mismatch++;
        } else {
          failure++;
        }
      }
    }
    final total = success + mismatch + error + failure;
    assert(total != 0);
    if (success < total) {
      buffer.writeln('Key $key:');
      buffer.writeln(' - static type: $staticType');
      buffer.writeln(' - runtime types: $runtimeTypes');
      final category = (String cat, int val) =>
        buffer.writeln(' - $cat: $val (${val / total})');
      category('success', success);
      category('failure', failure);
      category('mismatch', mismatch);
      category('error', error);
    }
  });
  if (clear) {
    _recordMap.clear();
  }
  return buffer.toString();
}
