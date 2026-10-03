import 'package:floafinwatch/features/auth/domain/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel Role Resolution Tests', () {
    test('identifies ryu_dev role correctly as developer', () {
      final user = UserModel(
        id: 1,
        name: 'Fahd Dev',
        email: 'dev@cib.co.id',
        roles: const ['ryu_dev'],
      );

      expect(user.isDeveloper, isTrue);
    });

    test('rejects non-developer roles', () {
      final user = UserModel(
        id: 2,
        name: 'Regular Admin',
        email: 'admin@cib.co.id',
        roles: const ['admin', 'journal_manager'],
      );

      expect(user.isDeveloper, isFalse);
    });

    test('parses roles from backend spatie permission format', () {
      final json = {
        'id': 5,
        'name': 'Ryu Dev',
        'email': 'ryu@cib.co.id',
        'roles': [
          {'id': 1, 'name': 'ryu_dev', 'guard_name': 'web'},
        ],
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 5);
      expect(user.roles, contains('ryu_dev'));
      expect(user.isDeveloper, isTrue);
    });

    test('serializes and deserializes accurately', () {
      final user = UserModel(
        id: 10,
        name: 'Test Dev',
        email: 'test@dev.com',
        roles: const ['ryu_dev'],
      );

      final raw = user.toRawJson();
      final restored = UserModel.fromRawJson(raw);

      expect(restored.id, user.id);
      expect(restored.name, user.name);
      expect(restored.email, user.email);
      expect(restored.roles, user.roles);
    });
  });
}
