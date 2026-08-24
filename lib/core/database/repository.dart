import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Base for the local-data repositories.
///
/// Each repository owns a change signal so the UI can hold a live query
/// (SPEC 26 "database-backed reactive state") without polling. Writes go
/// through [notifyChanged], and [watch] turns any read into a stream that
/// re-runs whenever the underlying table changes.
abstract class Repository {
  Repository(this.database);

  final AppDatabase database;

  Database get db => database.db;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Emits after every write performed through this repository.
  Stream<void> get changes => _changes.stream;

  /// Signals watchers that data changed.
  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Re-runs [read] once immediately and again on every change.
  ///
  /// Errors from [read] are forwarded to the stream rather than swallowed, so a
  /// broken query surfaces in the UI instead of showing a stale empty list.
  Stream<T> watch<T>(Future<T> Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;
    var closed = false;

    Future<void> emit() async {
      try {
        final value = await read();
        if (!closed) controller.add(value);
      } catch (error, stackTrace) {
        if (!closed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        subscription = changes.listen((_) => unawaited(emit()));
        unawaited(emit());
      },
      onCancel: () async {
        closed = true;
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> dispose() => _changes.close();
}
