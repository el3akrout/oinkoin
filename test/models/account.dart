import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/account.dart';

void main() {
  group('Account model', () {
    group('toMap', () {
      test('serializes all fields', () {
        final account = Account(
          'Cash',
          id: 3,
          color: const Color.fromARGB(255, 76, 175, 80),
          iconCodePoint: 0xe57b,
          initialBalance: 500.0,
        );
        final map = account.toMap();

        expect(map['id'], 3);
        expect(map['name'], 'Cash');
        expect(map['initial_balance'], 500.0);
        expect(map['icon'], 0xe57b);
        // Color serialized as "A:R:G:B"
        expect(map['color'], isA<String>());
        expect(map['color'].contains(':'), isTrue);
      });

      test('omits id when null', () {
        final account = Account('Cash');
        final map = account.toMap();
        expect(map.containsKey('id'), isFalse);
      });

      test('sets color to null when no color', () {
        final account = Account('Cash');
        final map = account.toMap();
        expect(map['color'], isNull);
      });

      test('currentBalance is not included in toMap', () {
        final account = Account('Cash', currentBalance: 999.0);
        final map = account.toMap();
        expect(map.containsKey('current_balance'), isFalse);
      });
    });

    group('fromMap', () {
      test('parses all fields', () {
        final map = {
          'id': 5,
          'name': 'Savings',
          'initial_balance': 1000.0,
          'icon': 0xe57b,
          'color': '255:76:175:80',
        };
        final account = Account.fromMap(map);

        expect(account.id, 5);
        expect(account.name, 'Savings');
        expect(account.initialBalance, 1000.0);
        expect(account.iconCodePoint, 0xe57b);
        expect(account.color, isNotNull);
      });

      test('parses current_balance if present', () {
        final map = {
          'id': 1,
          'name': 'Checking',
          'initial_balance': 100.0,
          'current_balance': 350.0,
        };
        final account = Account.fromMap(map);
        expect(account.currentBalance, 350.0);
      });

      test('currentBalance is null when absent', () {
        final map = {
          'id': 1,
          'name': 'Checking',
          'initial_balance': 100.0,
        };
        final account = Account.fromMap(map);
        expect(account.currentBalance, isNull);
      });

      test('handles null color gracefully', () {
        final map = {
          'id': 1,
          'name': 'Cash',
          'initial_balance': 0.0,
          'color': null,
        };
        final account = Account.fromMap(map);
        expect(account.color, isNull);
      });

      test('defaults initialBalance to 0.0 when absent', () {
        final map = {
          'id': 1,
          'name': 'Cash',
        };
        final account = Account.fromMap(map);
        expect(account.initialBalance, 0.0);
      });
    });

    group('color round-trip', () {
      test('serializes and deserializes color correctly', () {
        final original = const Color.fromARGB(255, 33, 150, 243);
        final account = Account('Test', color: original);
        final map = account.toMap();
        // Inject as string (as it would be stored in DB)
        map['id'] = 1;
        final restored = Account.fromMap(map);
        expect(restored.color?.value, original.value);
      });
    });

    group('equality', () {
      test('two accounts with same id are equal', () {
        final a = Account('Foo', id: 1);
        final b = Account('Bar', id: 1);
        expect(a, equals(b));
      });

      test('two accounts with different ids are not equal', () {
        final a = Account('Foo', id: 1);
        final b = Account('Foo', id: 2);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
