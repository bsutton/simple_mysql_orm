import 'package:di_zone2/di_zone2.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'db.dart';
import 'db_pool.dart';
import 'shared_pool.dart';

/// Obtains a connection and starts a MySQL transaction.
///
/// The [action] is called within the scope of the transaction.
/// When the [action] returns the transaction is automatically
/// committed.
/// If [action] throws any exception the transaction is
/// rolledback.
///
/// In most cases you will want to call [withTransaction] at the very
/// top of your call stack. This ensures that all db interactions occur
/// within the one transaction. This is important because any db interactions
/// that are performed outside of the transaction will not have visiblity
/// of the db changes associated with the transaction until the transaction
/// is committed.
///
/// MySQL does not allow nested transaction, therefore if you attempt
/// to nest a transation a [NestedTransactionException] is thrown unless...
///
/// Thre are some circumstances where you may want to call [withTransaction]
/// within the scope of an existing [withTransaction] call.
///
/// 1) you have a method that may or may not be called within the scope of an
/// existing [withTransaction] call.
/// In this case pass [nesting] = [TransactionNesting.nested].
///
/// If you code is called within the scope of an existing [withTransaction]
/// call then it will be attached to the same [Db] connection and the
/// same transaction. This is still NOT a nested MYSQL transaction and
/// if you transaction fails the outer one will also fail.
///
/// If your code is called outside the scope of an existing [withTransaction]
/// then a new [Db] connection will be obtained and a MySQL transaction
/// started.
///
/// 2) you may need to start a second MySQL transaction whilst in the scope
/// of a [withTransaction] call.
///
/// In this case pass [TransactionNesting.detached].
/// A new [Db] connection will be obtained and a new MySQL transaction
/// will be started. You need to be careful that you don't create a live
/// lock (two transactions viaing for the same resources).
///
/// [useTransaction] is intended for debugging purposes.
/// By setting [useTransaction] any db changes are visible
/// as soon as the occur rather than only once the transaction
/// completes. So this option allows you to inspect the db
/// as updates occur.
Future<R> withTransaction<R>(Future<R> Function() action,
    {TransactionNesting nesting = TransactionNesting.notAllowed,
    bool useTransaction = true}) async {
  final nestedTransaction = Scope.hasScopeKey(Transaction.transactionKey);

  switch (nesting) {
    case TransactionNesting.notAllowed:
      if (nestedTransaction) {
        throw NestedTransactionException('You are already in a transaction. '
            'Specify TransactionNesting.nestedTransaction');
      }
      return _runTransaction(action,
          useTransaction: useTransaction, shareDb: false);

    case TransactionNesting.detached:
      return _runTransaction(action,
          useTransaction: useTransaction, shareDb: false);

    case TransactionNesting.nested:
      return _runTransaction(action,
          useTransaction: useTransaction && !nestedTransaction,
          shareDb: nestedTransaction);
  }
}

Future<R> _runTransaction<R>(Future<R> Function() action,
    {required bool useTransaction, required bool shareDb}) async {
  ConnectionWrapper<Db>? wrapper;

  Db db;
  if (shareDb) {
    db = Transaction.current.db;
  } else {
    wrapper = await DbPool().obtain();
    db = wrapper.wrapped;
  }

  final transaction = Transaction<R>(db, useTransaction: useTransaction);

  return (Scope()..value(Transaction.transactionKey, transaction))
      .run(() async {
    try {
      return await transaction.run(action);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (wrapper != null) {
        await DbPool().release(wrapper);
      }
      rethrow;
    }
  });
}

class NestedTransactionException implements Exception {
  NestedTransactionException(this.message);
  String message;
}

enum TransactionNesting {
  detached,
  nested,
  notAllowed,
}

class Transaction<R> {
  /// Create a database transaction for [db].
  ///
  /// If [useTransaction] is false the transation
  /// isn't created. This should only be used for debugging.
  Transaction(this.db, {required this.useTransaction}) : id = nextId++ {
    // _begin();
  }

  final logger = Logger('Transaction');

  static int nextId = 0;

  /// unique id used for debugging
  int id;

  static Transaction get current => use(transactionKey);
  final Db db;

  /// For debugging purposes the user can suppress
  /// the use of a transaction so that they can see db
  /// updates as they happen.
  final bool useTransaction;

  bool _commited = false;

  @visibleForTesting
  static final ScopeKey<Transaction> transactionKey =
      ScopeKey<Transaction>('transaction');

  // Transaction get transaction => use(transactionKey);

  /// [useTransaction] is intended for debugging purposes.
  /// By setting [useTransaction] and db changes are visible
  /// as soon as the occur rather than only once the transaction
  /// completes. So this option allows you to inspect the db
  /// as updates occur.
  Future<R> run(Future<R> Function() action) async {
    logger.info(() =>
        'Start transaction($id db: ${db.id}): useTransaction: $useTransaction');
    if (!useTransaction) {
      final result = await action();
      _commited = true;
      logger.info(() =>
          'End transaction($id db: ${db.id}): useTransaction: $useTransaction');
      return result;
    } else {
      final result = await db.transaction(() async => action());
      _commited = true;
      logger.info(() =>
          'End transaction($id db: ${db.id}): useTransaction: $useTransaction');
      return result;
    }
  }

  // /// The transaction has started
  // bool started = false;

  // /// The transation has been commtied
  // bool committed = false;

  // /// Transaction
  // bool rolledback = false;

  // void _begin() {
  //   if (started == true) {
  //     throw InvalidTransactionStateException(
  //'begin has already been called');
  //   }
  //   db.begin();
  //   started = true;
  // }

  // void _commit() {
  //   if (committed) {
  //     throw InvalidTransactionStateException(
  //'commit has already been called');
  //   }
  //   db.commit();
  //   committed = true;
  // }

  void rollback() {
    if (!useTransaction) {
      return;
    }
    if (_commited) {
      throw InvalidTransactionStateException('commit has already been called');
    }

    db.rollback();
  }
}

class InvalidTransactionStateException implements Exception {
  InvalidTransactionStateException(this.message);
  String message;
}
