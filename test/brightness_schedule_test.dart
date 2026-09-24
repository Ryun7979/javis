import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/util/brightness_schedule.dart';

void main() {
  group('isScheduledDim', () {
    test('2:00〜18:59は暗い、19:00〜翌1:59は明るい', () {
      expect(isScheduledDim(DateTime(2026, 9, 24, 1, 59)), isFalse);
      expect(isScheduledDim(DateTime(2026, 9, 24, 2, 0)), isTrue);
      expect(isScheduledDim(DateTime(2026, 9, 24, 12, 0)), isTrue);
      expect(isScheduledDim(DateTime(2026, 9, 24, 18, 59)), isTrue);
      expect(isScheduledDim(DateTime(2026, 9, 24, 19, 0)), isFalse);
      expect(isScheduledDim(DateTime(2026, 9, 24, 23, 59)), isFalse);
      expect(isScheduledDim(DateTime(2026, 9, 25, 0, 0)), isFalse);
    });
  });

  group('nextScheduleBoundary', () {
    test('深夜は当日2:00', () {
      expect(nextScheduleBoundary(DateTime(2026, 9, 24, 0, 30)),
          DateTime(2026, 9, 24, 2));
    });
    test('日中は当日19:00', () {
      expect(nextScheduleBoundary(DateTime(2026, 9, 24, 2, 0)),
          DateTime(2026, 9, 24, 19));
      expect(nextScheduleBoundary(DateTime(2026, 9, 24, 18, 59)),
          DateTime(2026, 9, 24, 19));
    });
    test('夜は翌日2:00（月末も繰り上がる）', () {
      expect(nextScheduleBoundary(DateTime(2026, 9, 24, 19, 0)),
          DateTime(2026, 9, 25, 2));
      expect(nextScheduleBoundary(DateTime(2026, 9, 30, 23, 0)),
          DateTime(2026, 10, 1, 2));
    });
  });
}
