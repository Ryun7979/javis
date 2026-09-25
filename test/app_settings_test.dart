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

  test('記事の自動クローズ時間はJSONで保存・復元できる', () {
    final settings =
        AppSettings.defaults().copyWith(articleAutoCloseMinutes: 10);
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.articleAutoCloseMinutes, 10);
  });

  test('自動クローズ時間を含まない古い保存データは既定値で復元する', () {
    final json = AppSettings.defaults().toJson()
      ..remove('articleAutoCloseMinutes');
    final restored = AppSettings.fromJson(json);
    expect(restored.articleAutoCloseMinutes,
        AppSettings.defaultArticleAutoCloseMinutes);
  });

  test('釣り情報/雨雲レーダーの切り替え間隔はJSONで保存・復元できる', () {
    final settings =
        AppSettings.defaults().copyWith(panelSwitchIntervalMinutes: 0);
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.panelSwitchIntervalMinutes, 0);
  });

  test('切り替え間隔を含まない古い保存データは既定値（10分）で復元する', () {
    final json = AppSettings.defaults().toJson()
      ..remove('panelSwitchIntervalMinutes');
    final restored = AppSettings.fromJson(json);
    expect(restored.panelSwitchIntervalMinutes, 10);
  });
}
