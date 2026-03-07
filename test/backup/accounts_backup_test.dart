import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:piggybank/models/account.dart';
import 'package:piggybank/models/backup.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record-tag-association.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:test/test.dart' as testlib;

import 'backup_service_test.mocks.dart';

void main() {
  // ── Backup model round-trip ────────────────────────────────────────────────
  group('Backup model — accounts', () {
    final account1 = Account('Cash', id: 1, initialBalance: 100.0,
        color: const Color.fromARGB(255, 76, 175, 80), iconCodePoint: 0xe57b);
    final account2 = Account('Bank', id: 2, initialBalance: 500.0);

    final category = Category('Food',
        iconCodePoint: 1, categoryType: CategoryType.expense);

    test('toMap includes accounts list', () {
      final backup = Backup(
        'com.app', '1.0', '18', [category], [], [], [],
        accounts: [account1, account2],
      );
      final map = backup.toMap();
      expect(map.containsKey('accounts'), isTrue);
      expect((map['accounts'] as List).length, 2);
    });

    test('fromMap restores accounts', () {
      final backup = Backup(
        'com.app', '1.0', '18', [category], [], [], [],
        accounts: [account1, account2],
      );
      final restored = Backup.fromMap(backup.toMap());
      expect(restored.accounts.length, 2);
      expect(restored.accounts.map((a) => a.name).toSet(),
          containsAll(['Cash', 'Bank']));
    });

    test('fromMap without accounts key still works (backward compat)', () {
      final map = {
        'records': [],
        'categories': [],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': 0,
        'package_name': '',
        'version': '',
        'database_version': '',
        // no 'accounts' key
      };
      final backup = Backup.fromMap(map);
      expect(backup.accounts, isEmpty);
    });

    test('accounts key = null is handled gracefully', () {
      final map = {
        'records': [],
        'categories': [],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'accounts': null,
        'created_at': 0,
        'package_name': '',
        'version': '',
        'database_version': '',
      };
      final backup = Backup.fromMap(map);
      expect(backup.accounts, isEmpty);
    });

    test('account color survives JSON encode/decode round-trip', () {
      final original = const Color.fromARGB(255, 33, 150, 243);
      final acct = Account('Blue', id: 1, color: original);
      final backup = Backup(
        'com.app', '1.0', '18', [category], [], [], [],
        accounts: [acct],
      );
      final json = jsonEncode(backup.toMap());
      final restored = Backup.fromMap(jsonDecode(json));
      expect(restored.accounts.first.color?.value, original.value);
    });

    test('fromMap resolves account_id to Account object on records', () {
      final acct = Account('MyBank', id: 42, initialBalance: 0.0);
      final record = Record(
        -50.0, 'Test', category, DateTime.utc(2024, 1, 1),
        id: 1,
        account: acct,
      );
      final backup = Backup(
        'com.app', '1.0', '18', [category], [record], [], [],
        accounts: [acct],
      );
      final restored = Backup.fromMap(jsonDecode(jsonEncode(backup.toMap())));
      expect(restored.records.first!.account, isNotNull);
      expect(restored.records.first!.account!.id, 42);
    });

    test('records with account_id survive JSON encode/decode round-trip', () {
      final acct = Account('MyBank', id: 42, initialBalance: 0.0);
      final record = Record(
        -50.0, 'Test', category, DateTime.utc(2024, 1, 1),
        id: 1,
        account: acct,
        transferId: 'uuid-123',
      );
      final backup = Backup(
        'com.app', '1.0', '18', [category], [record], [], [],
        accounts: [acct],
      );
      final json = jsonEncode(backup.toMap());
      final map = jsonDecode(json) as Map<String, dynamic>;

      // account_id is stored in record map
      final recordMap = (map['records'] as List).first as Map<String, dynamic>;
      expect(recordMap['account_id'], 42);
      expect(recordMap['transfer_id'], 'uuid-123');
    });
  });

  // ── BackupService with mock ─────────────────────────────────────────────────
  group('BackupService — accounts', () {
    late MockDatabaseInterface mockDatabase;
    late Directory testDir;

    final category = Category('Food',
        iconCodePoint: 1, categoryType: CategoryType.expense);
    final account = Account('Cash',
        id: 1, initialBalance: 200.0,
        color: Colors.green[300]);
    final record = Record(
      -50.0, 'Groceries', category, DateTime.parse('2024-03-01 10:00:00Z'),
      id: 1,
      account: account,
    );

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockDatabase = MockDatabaseInterface();

      when(mockDatabase.getAllRecords()).thenAnswer((_) async => [record]);
      when(mockDatabase.getAllCategories()).thenAnswer((_) async => [category]);
      when(mockDatabase.getRecurrentRecordPatterns()).thenAnswer((_) async => []);
      when(mockDatabase.getAllRecordTagAssociations())
          .thenAnswer((_) async => []);
      when(mockDatabase.getAllAccounts()).thenAnswer((_) async => [account]);

      when(mockDatabase.addCategory(any)).thenAnswer((_) async => 0);
      when(mockDatabase.addRecord(any)).thenAnswer((_) async => 0);
      when(mockDatabase.addRecordsInBatch(any)).thenAnswer((_) async => null);
      when(mockDatabase.addRecurrentRecordPattern(any))
          .thenAnswer((_) async => null);
      when(mockDatabase.getRecurrentRecordPattern(any))
          .thenAnswer((_) async => null);
      when(mockDatabase.getMatchingRecord(any)).thenAnswer((_) async => null);
      when(mockDatabase.addAccount(any)).thenAnswer((_) async => 99);

      BackupService.database = mockDatabase;

      testDir = Directory('test/temp_accounts');
      const MethodChannel pkgChannel =
          MethodChannel('dev.fluttercommunity.plus/package_info');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pkgChannel, (call) async {
        if (call.method == 'getAll') {
          return {
            'appName': 'test',
            'packageName': 'com.test',
            'version': '1.0',
            'buildNumber': '1',
          };
        }
      });
      const MethodChannel pathChannel =
          MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => testDir.path);
    });

    testlib.setUp(() async {
      if (await testDir.exists()) await testDir.delete(recursive: true);
      await testDir.create(recursive: true);
    });

    tearDownAll(() async {
      if (await testDir.exists()) await testDir.delete(recursive: true);
    });

    test('createJsonBackupFile includes accounts in backup JSON', () async {
      final file = await BackupService.createJsonBackupFile(
          directoryPath: testDir.path);
      final content = jsonDecode(await file.readAsString());
      expect(content.containsKey('accounts'), isTrue);
      final accounts = content['accounts'] as List;
      expect(accounts.length, 1);
      expect(accounts.first['name'], 'Cash');
    });

    test('importDataFromBackupFile remaps account IDs on records before inserting',
        () async {
      // Build a backup: account id=10 in backup, addAccount returns 99 (new id)
      final backupAccount = Account('Wallet', id: 10, initialBalance: 0.0);
      final backupRecord = Record(
        -30.0, 'Groceries', category, DateTime.utc(2024, 1, 1),
        id: 1,
        account: backupAccount,
      );
      final backup = Backup(
        'com.app', '1.0', '18', [category], [backupRecord], [], [],
        accounts: [backupAccount],
      );

      List<Record?>? capturedRecords;
      when(mockDatabase.addRecordsInBatch(any)).thenAnswer((inv) async {
        capturedRecords = List<Record?>.from(inv.positionalArguments[0] as List);
      });

      final file = File('${testDir.path}/remap_test.obackup.json');
      await file.writeAsString(jsonEncode(backup.toMap()));
      await BackupService.importDataFromBackupFile(file);

      // addAccount returns 99 (stubbed in setUpAll), so record.account.id must be 99
      expect(capturedRecords, isNotNull);
      expect(capturedRecords!.first!.account, isNotNull);
      expect(capturedRecords!.first!.account!.id, 99);
    });

    test('importDataFromBackupFile calls addAccount for each backup account',
        () async {
      // Build a backup file that contains one account
      final backupData = {
        'records': [],
        'categories': [],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'accounts': [
          {
            'id': 10,
            'name': 'Imported Account',
            'initial_balance': 300.0,
          }
        ],
        'created_at': 0,
        'package_name': 'com.test',
        'version': '1.0',
        'database_version': '18',
      };
      final file = File('${testDir.path}/test_import.obackup.json');
      await file.writeAsString(jsonEncode(backupData));

      await BackupService.importDataFromBackupFile(file);

      verify(mockDatabase.addAccount(argThat(
        predicate<Account>((a) => a.name == 'Imported Account'),
      ))).called(1);
    });
  });
}
