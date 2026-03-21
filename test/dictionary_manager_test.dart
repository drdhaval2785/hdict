import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';


void main() {
  group('DictionaryManager Data Classes', () {
    test('ImportProgress initialization', () {
      final progress = ImportProgress(
        message: 'Testing',
        value: 0.5,
        headwordCount: 100,
        dictionaryName: 'Test Dict',
      );

      expect(progress.message, 'Testing');
      expect(progress.value, 0.5);
      expect(progress.headwordCount, 100);
      expect(progress.dictionaryName, 'Test Dict');
      expect(progress.isCompleted, isFalse);
    });

    test('DeletionProgress initialization', () {
      final progress = DeletionProgress(
        message: 'Deleting',
        value: 0.8,
        isCompleted: true,
      );

      expect(progress.message, 'Deleting');
      expect(progress.value, 0.8);
      expect(progress.isCompleted, isTrue);
    });
  });
}
