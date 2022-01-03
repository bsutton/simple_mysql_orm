@Timeout(Duration(minutes: 3))

import 'package:dcli/dcli.dart' hide equals;
import 'package:di_zone2/di_zone2.dart';
import 'package:logging/logging.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

import '../../test_dao/dao/uploader_dao.dart';
import '../../test_dao/model/publisher.dart';

final settingsPath = join('test', 'settings.yaml');
void main() {
  setUpAll(() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  });

  setUp(() {
    if (!exists(dirname(settingsPath))) {
      createDir(dirname(settingsPath), recursive: true);
    }
    DbPool.fromSettings(pathToSettings: settingsPath);
  });

  test('transaction ... obtain/release', () async {
    await withTransaction(() async {
      expect(() => DbPool().close(), throwsA(isA<MySQLException>()));
    });
    await DbPool().close();
  });
  test('transaction ...', () async {
    var ran = false;
    await withTransaction(() async {
      final db = Transaction.current.db;
      expect(db, isNotNull);
      final dao = PublisherDao();
      await dao.delete().where().eq('name', 'brett').run();
      final publisher = Publisher(name: 'brett', email: 'me@my.com');
      final identity = await dao.persist(publisher);
      final inserted = await dao.getById(identity);

      expect(inserted, isNotNull);
      expect(inserted!.name, equals('brett'));
      expect(inserted.email, equals('me@my.com'));
      ran = true;
    });
    expect(ran, isTrue);
    await DbPool().close();
  });

  test('invalid nested transaction ...', () async {
    await expectLater(
        () async => withTransaction(() async {
              await withTransaction(() async {});
            }),
        throwsA(isA<NestedTransactionException>()));
    await DbPool().close();
  });

  test('multiple transactions - different db', () async {
    final used = <int>[];

    final a = Future.delayed(
        const Duration(seconds: 1),
        () => withTransaction<void>(() {
              used.add(Transaction.current.db.id);
              return Future.delayed(const Duration(seconds: 10));
            }));
    final b = Future.delayed(
        const Duration(seconds: 1),
        () => withTransaction<void>(() {
              used.add(Transaction.current.db.id);
              return Future.delayed(const Duration(seconds: 10));
            }));

    final c = Future.delayed(
        const Duration(seconds: 1),
        () => withTransaction<void>(() {
              used.add(Transaction.current.db.id);
              return Future.delayed(const Duration(seconds: 10));
            }));

    await Future.wait([a, b, c]);
    expect(used, unorderedEquals(<int>[0, 1, 2]));
  });
  test('transaction with result', () async {
    final count = await withTransaction<int>(() async => 1);
    expect(count, 1);

    final name = await withTransaction<String?>(() async => null);
    expect(name, isNull);
  });
  test('nested with no nesting transaction ...', () async {
    var ran = false;
    await withTransaction(() async {
      ran = true;
      expect(Scope.hasScopeKey(Transaction.transactionKey), isTrue);
    }, nesting: TransactionNesting.nested);
    expect(ran, isTrue);
    await DbPool().close();
  });
  test('valid nested transaction ...', () async {
    var ran = false;
    Db db;
    await withTransaction(() async {
      db = Transaction.current.db;
      await withTransaction(() async {
        expect(db, equals(Transaction.current.db));
        ran = true;
      }, nesting: TransactionNesting.nested);
    });
    expect(ran, isTrue);
    await DbPool().close();
  });

  test('detached nested transaction ...', () async {
    var ran = false;
    Db db;
    await withTransaction(() async {
      db = Transaction.current.db;
      await withTransaction(() async {
        ran = true;
        expect(db, isNot(equals(Transaction.current.db)));
      }, nesting: TransactionNesting.detached);
    });
    expect(ran, isTrue);
    await DbPool().close();
  });

  test('!useTransaction ...', () async {
    var ran = false;
    Db db;
    await withTransaction(() async {
      db = Transaction.current.db;
      await withTransaction(() async {
        ran = true;
        expect(db, isNot(equals(Transaction.current.db)));
      }, nesting: TransactionNesting.detached);
    }, useTransaction: false);
    expect(ran, isTrue);
    await DbPool().close();
  });
}
