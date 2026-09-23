# wall_jarvis

釣り・ニュース・時計ダッシュボードアプリ。Androidタブレットを卓上キオスクとして常時設置し、
大型時計・釣り場の潮汐/天気・ゲーム/AI/ITニュースを自動更新表示する。Flutter / Dart製。

- applicationId: `com.nadaryu.wall_jarvis`
- 詳細仕様: `docs/2026-09-23-仕様書.pdf`
- 開発方針・作業ルール: [CLAUDE.md](CLAUDE.md)
- セッションをまたいだ作業記憶（環境構築の手順・既知の落とし穴など）: [LEARNINGS.md](LEARNINGS.md)

## セットアップ

CLAUDE.mdの「開発環境の起動手順」を参照。Flutter SDK・Android SDK・JDKの導入後、
`flutter doctor -v` で全項目が通ることを確認してから作業する。

## 検証

```
flutter analyze
flutter test
```

UIに関わる変更は上記に加えて実機またはエミュレータで動作確認する。
