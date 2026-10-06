import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/settings/application/backup_restore_progress.dart';

void main() {
  test('large libraries never reset progress at multiples of 500', () {
    var previous = 0.4;
    for (var i = 0; i <= 10000; i++) {
      final value = libraryRestoreProgress(completed: i, total: 10000)!;
      expect(value, greaterThanOrEqualTo(previous));
      expect(value, inInclusiveRange(0.4, 0.7));
      previous = value;
    }
    expect(previous, closeTo(0.7, 0.000001));
  });
  test('streaming without a total stays indeterminate', () {
    expect(libraryRestoreProgress(completed: 1500, total: null), isNull);
  });
  test('empty and overshooting phases finish without overflow', () {
    expect(libraryRestoreProgress(completed: 0, total: 0), 0.7);
    expect(libraryRestoreProgress(completed: 20, total: 10), 0.7);
  });
}
