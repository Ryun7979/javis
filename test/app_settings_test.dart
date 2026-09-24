import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/models/app_settings.dart';
import 'package:wall_jarvis/util/brightness_schedule.dart';

void main() {
  test('輝度設定はJSONで保存・復元できる', () {
    final settings = AppSettings.defaults()
        .copyWith(dimBrightness: 0.3, brightBrightness: 0.8);
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.dimBrightness, 0.3);
    expect(restored.brightBrightness, 0.8);
  });

  test('輝度設定を含まない古い保存データは既定値で復元する', () {
    final json = AppSettings.defaults().toJson()
      ..remove('dimBrightness')
      ..remove('brightBrightness');
    final restored = AppSettings.fromJson(json);
    expect(restored.dimBrightness, defaultDimBrightness);
    expect(restored.brightBrightness, defaultBrightBrightness);
  });
}
