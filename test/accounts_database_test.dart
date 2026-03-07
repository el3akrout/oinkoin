import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/account.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

void main() {
  final testCategory = Category(
    'TestExpense',
    iconCodePoint: 1,
    categoryType: CategoryType.expense,
    color: Colors.blue,
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'Europe/London';
  });

  setUp(() async {
    // Each test gets a fresh isolated in-memory database.
    await TestDatabaseHelper.setupTestDatabase();
  });

  // ── Account CRUD ─────────────────────────────────────────────────────────
  group('Account CRUD', () {
    test('addAccount returns a valid id', () async {
      final db = ServiceConfig.database;
      final id = await db.addAccount(Account('Cash', initialBalance: 100.0));
      expect(id, greaterThan(0));
    });

    test('getAllAccounts returns inserted account', () async {
      final db = ServiceConfig.database;
      await db.addAccount(Account('Savings', initialBalance: 500.0));
      final accounts = await db.getAllAccounts();
      expect(accounts.length, 1);
      expect(accounts.first.name, 'Savings');
      expect(accounts.first.initialBalance, 500.0);
    });

    test('getAllAccounts returns accounts ordered by name', () async {
      final db = ServiceConfig.database;
      await db.addAccount(Account('Zorro', initialBalance: 0.0));
      await db.addAccount(Account('Alpha', initialBalance: 0.0));
      await db.addAccount(Account('Mango', initialBalance: 0.0));
      final names = (await db.getAllAccounts()).map((a) => a.name).toList();
      expect(names, ['Alpha', 'Mango', 'Zorro']);
    });

    test('getAccountById returns the correct account', () async {
      final db = ServiceConfig.database;
      final id =
          await db.addAccount(Account('Checking', initialBalance: 200.0));
      final account = await db.getAccountById(id);
      expect(account, isNotNull);
      expect(account!.name, 'Checking');
      expect(account.id, id);
    });

    test('getAccountById returns null for nonexistent id', () async {
      final account = await ServiceConfig.database.getAccountById(9999);
      expect(account, isNull);
    });

    test('updateAccount modifies existing account', () async {
      final db = ServiceConfig.database;
      final id = await db.addAccount(Account('Old Name', initialBalance: 0.0));
      await db.updateAccount(id, Account('New Name', initialBalance: 999.0));
      final updated = await db.getAccountById(id);
      expect(updated!.name, 'New Name');
      expect(updated.initialBalance, 999.0);
    });

    test('deleteAccount removes the account', () async {
      final db = ServiceConfig.database;
      final id = await db.addAccount(Account('ToDelete'));
      await db.deleteAccount(id);
      expect(await db.getAccountById(id), isNull);
    });

    test('deleteDatabase removes all accounts', () async {
      final db = ServiceConfig.database;
      await db.addAccount(Account('Cash'));
      await db.addAccount(Account('Bank'));
      await db.deleteDatabase();
      await TestDatabaseHelper.setupTestDatabase();
      expect(await ServiceConfig.database.getAllAccounts(), isEmpty);
    });

    test('deleteAccount nulls out account_id on linked records but keeps records',
        () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      final id = await db.addAccount(Account('Bank'));
      await db.addRecord(Record(
        -50.0, 'Groceries', testCategory, DateTime.now().toUtc(),
        account: Account('Bank', id: id),
      ));

      await db.deleteAccount(id);

      expect(await db.getAccountById(id), isNull);
      final records = await db.getAllRecords();
      expect(records.length, 1);
      expect(records.first!.account, isNull);
    });
  });

  // ── Balance computation ───────────────────────────────────────────────────
  group('Account balance computation', () {
    test('balance equals initialBalance when no linked records', () async {
      final db = ServiceConfig.database;
      final id =
          await db.addAccount(Account('Wallet', initialBalance: 250.0));
      final account = await db.getAccountById(id);
      expect(account!.currentBalance, 250.0);
    });

    test('balance reflects linked record values', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      final id =
          await db.addAccount(Account('Wallet', initialBalance: 200.0));
      final acct = Account('Wallet', id: id);

      await db.addRecord(
          Record(-30.0, 'Coffee', testCategory, DateTime.now().toUtc(),
              account: acct));
      await db.addRecord(
          Record(-20.0, 'Lunch', testCategory, DateTime.now().toUtc(),
              account: acct));

      final updated = await db.getAccountById(id);
      expect(updated!.currentBalance, 150.0); // 200 - 30 - 20
    });

    test('getAllAccounts returns computed balances', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      final id =
          await db.addAccount(Account('Savings', initialBalance: 1000.0));
      await db.addRecord(Record(
        -100.0, 'Bill', testCategory, DateTime.now().toUtc(),
        account: Account('Savings', id: id),
      ));
      final accounts = await db.getAllAccounts();
      expect(accounts.first.currentBalance, 900.0);
    });
  });

  // ── getTotalBalance ───────────────────────────────────────────────────────
  group('getTotalBalance', () {
    test('returns 0 when no accounts and no records', () async {
      expect(await ServiceConfig.database.getTotalBalance(), 0.0);
    });

    test('returns sum of initial balances when no records', () async {
      final db = ServiceConfig.database;
      await db.addAccount(Account('A', initialBalance: 300.0));
      await db.addAccount(Account('B', initialBalance: 200.0));
      expect(await db.getTotalBalance(), 500.0);
    });

    test('includes unassigned records in total', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      await db.addAccount(Account('Bank', initialBalance: 1000.0));
      // Expense with no account
      await db.addRecord(Record(-150.0, 'Old expense', testCategory, DateTime.now().toUtc()));
      expect(await db.getTotalBalance(), 850.0);
    });

    test('includes assigned records in total', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      final id = await db.addAccount(Account('Bank', initialBalance: 1000.0));
      await db.addRecord(Record(-200.0, 'Rent', testCategory, DateTime.now().toUtc(),
          account: Account('Bank', id: id)));
      expect(await db.getTotalBalance(), 800.0);
    });

    test('mixed assigned and unassigned records both contribute', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      final id = await db.addAccount(Account('Bank', initialBalance: 1000.0));
      await db.addRecord(Record(-100.0, 'Assigned', testCategory, DateTime.now().toUtc(),
          account: Account('Bank', id: id)));
      await db.addRecord(Record(-50.0, 'Unassigned', testCategory, DateTime.now().toUtc()));
      expect(await db.getTotalBalance(), 850.0);
    });

    test('transfers do not double-count (cancel out)', () async {
      final db = ServiceConfig.database;
      final fromId = await db.addAccount(Account('Checking', initialBalance: 500.0));
      final toId = await db.addAccount(Account('Savings', initialBalance: 200.0));
      await db.addTransfer(
        Account('Checking', id: fromId),
        Account('Savings', id: toId),
        100.0,
        DateTime.now().toUtc(),
      );
      // Transfer = -100 + 100 = 0 net, total stays 700
      expect(await db.getTotalBalance(), 700.0);
    });
  });

  // ── Transfers ─────────────────────────────────────────────────────────────
  group('Transfer', () {
    test('addTransfer creates two records sharing the same transfer_id',
        () async {
      final db = ServiceConfig.database;
      final fromId =
          await db.addAccount(Account('Checking', initialBalance: 500.0));
      final toId =
          await db.addAccount(Account('Savings', initialBalance: 0.0));

      await db.addTransfer(
        Account('Checking', id: fromId),
        Account('Savings', id: toId),
        100.0,
        DateTime.now().toUtc(),
      );

      final records = await db.getAllRecords();
      expect(records.length, 2);
      final ids = records.map((r) => r!.transferId).toSet();
      expect(ids.length, 1);
      expect(ids.first, isNotNull);
    });

    test('addTransfer adjusts both account balances correctly', () async {
      final db = ServiceConfig.database;
      final fromId =
          await db.addAccount(Account('Checking', initialBalance: 500.0));
      final toId =
          await db.addAccount(Account('Savings', initialBalance: 100.0));

      await db.addTransfer(
        Account('Checking', id: fromId),
        Account('Savings', id: toId),
        200.0,
        DateTime.now().toUtc(),
      );

      final accounts = await db.getAllAccounts();
      final checking = accounts.firstWhere((a) => a.id == fromId);
      final savings = accounts.firstWhere((a) => a.id == toId);
      expect(checking.currentBalance, 300.0); // 500 - 200
      expect(savings.currentBalance, 300.0); // 100 + 200
    });

    test('transfer records have opposite value signs', () async {
      final db = ServiceConfig.database;
      final fromId = await db.addAccount(Account('A', initialBalance: 0.0));
      final toId = await db.addAccount(Account('B', initialBalance: 0.0));

      await db.addTransfer(
        Account('A', id: fromId),
        Account('B', id: toId),
        50.0,
        DateTime.now().toUtc(),
      );

      final values = (await db.getAllRecords()).map((r) => r!.value).toList()
        ..sort();
      expect(values, [-50.0, 50.0]);
    });

    test('deleteRecordById on one transfer leg deletes both legs', () async {
      final db = ServiceConfig.database;
      final fromId = await db.addAccount(Account('A', initialBalance: 0.0));
      final toId = await db.addAccount(Account('B', initialBalance: 0.0));

      await db.addTransfer(
        Account('A', id: fromId),
        Account('B', id: toId),
        75.0,
        DateTime.now().toUtc(),
      );

      final records = await db.getAllRecords();
      expect(records.length, 2);

      await db.deleteRecordById(records.first!.id);

      expect(await db.getAllRecords(), isEmpty);
    });

    test('deleteTransfer removes both legs by transferId', () async {
      final db = ServiceConfig.database;
      final fromId = await db.addAccount(Account('A', initialBalance: 0.0));
      final toId = await db.addAccount(Account('B', initialBalance: 0.0));

      await db.addTransfer(
        Account('A', id: fromId),
        Account('B', id: toId),
        50.0,
        DateTime.now().toUtc(),
      );

      final tid = (await db.getAllRecords()).first!.transferId!;
      await db.deleteTransfer(tid);

      expect(await db.getAllRecords(), isEmpty);
    });

    test('deleteRecordById for non-transfer record only deletes that record',
        () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      await db.addRecord(
          Record(-10.0, 'A', testCategory, DateTime.now().toUtc()));
      await db.addRecord(
          Record(-20.0, 'B', testCategory, DateTime.now().toUtc()));

      final records = await db.getAllRecords();
      expect(records.length, 2);
      await db.deleteRecordById(records.first!.id);
      expect((await db.getAllRecords()).length, 1);
    });
  });

  // ── JOIN in getAllRecords ──────────────────────────────────────────────────
  group('getAllRecords with account JOIN', () {
    test('record linked to account has account populated', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      final id =
          await db.addAccount(Account('MyBank', initialBalance: 0.0));
      await db.addRecord(Record(
        -99.0, 'Test', testCategory, DateTime.now().toUtc(),
        account: Account('MyBank', id: id),
      ));

      final record = (await db.getAllRecords()).first!;
      expect(record.account, isNotNull);
      expect(record.account!.name, 'MyBank');
      expect(record.account!.id, id);
    });

    test('record without account has account null', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      await db.addRecord(
          Record(-10.0, 'NoAcct', testCategory, DateTime.now().toUtc()));
      expect((await db.getAllRecords()).first!.account, isNull);
    });

    test('getAllRecordsInInterval includes account via JOIN', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      final id = await db.addAccount(Account('Joined', initialBalance: 0.0));
      final now = DateTime.now();
      await db.addRecord(Record(
        -5.0, 'Linked', testCategory, now.toUtc(),
        account: Account('Joined', id: id),
      ));

      final start = now.subtract(const Duration(days: 1));
      final end = now.add(const Duration(days: 1));
      final records = await db.getAllRecordsInInterval(start, end);
      expect(records.first!.account?.name, 'Joined');
    });
  });

  // ── getRecordsForAccount ──────────────────────────────────────────────────
  group('getRecordsForAccount', () {
    test('returns only records linked to the given account', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategory);
      final idA = await db.addAccount(Account('A'));
      final idB = await db.addAccount(Account('B'));

      await db.addRecord(Record(-10.0, 'r1', testCategory, DateTime.now().toUtc(),
          account: Account('A', id: idA)));
      await db.addRecord(Record(-20.0, 'r2', testCategory, DateTime.now().toUtc(),
          account: Account('B', id: idB)));
      await db.addRecord(Record(-30.0, 'r3', testCategory, DateTime.now().toUtc(),
          account: Account('A', id: idA)));

      final forA = await db.getRecordsForAccount(idA);
      expect(forA.length, 2);
      expect(forA.every((r) => r.account_id == idA), isTrue);
    });

    test('returns empty list for account with no records', () async {
      final db = ServiceConfig.database;
      final id = await db.addAccount(Account('Empty'));
      expect(await db.getRecordsForAccount(id), isEmpty);
    });
  });
}

extension _RecordExt on Record {
  int? get account_id => account?.id;
}
