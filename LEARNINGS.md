# Project Learnings

このファイルはセッションをまたいだ作業記憶です。各セッションの開始時に読み、作業の終わりに追記します。
1項目は 1〜3行。太字で主張を先頭に置き、根拠となった具体例と、次回の行動を続けます。

## Patterns That Work 効いたこと
<!-- 安く確実に目的を達した手順や調べ方。「次も同じ状況でそのまま使えるか」が基準 -->

- 開発環境を最初に作ったときの手順（Flutter SDK・sdkmanager・JDKの入れ方）は `docs/2026-10-04-開発環境の構築記録.md` に切り出した。
- **外部APIの固定長テキスト形式は、WebFetchの要約結果を信用せず`curl`で生データを取得し`cut -c`で
  桁位置を実測してから実装する。** 気象庁の潮位表テキスト（`data.jma.go.jp/kaiyou/data/db/tide/suisan/txt/`）
  はWebFetchの要約だと空白の桁数が崩れて誤読した（年が4桁に見えるなど）。生バイトを`cat -A`や`cut -c`で
  確認し、既知の極大/極小（満潮/干潮）の時刻・潮位と突き合わせて初めて正しいフォーマット
  （毎時潮位24×3桁＋年2桁＋月2桁＋日2桁＋地点2桁＋満潮4件×7桁＋干潮4件×7桁）を確定できた。
- **Riverpodでコード生成（riverpod_generator/hive_generator）が必要な機能は避け、legacy APIや
  手書きJSONシリアライズで済ませるとWindowsの「開発者モード」要求（symlink作成）を回避できる。**
  `build_runner`はWindowsでシンボリックリンク作成権限を要求し、開発者モード有効化はシステム設定変更に
  当たるため避けたい。`package:flutter_riverpod/legacy.dart`の`StateNotifierProvider`は
  コード生成なしで使える。Hiveも`hive_generator`のTypeAdapterではなく`jsonEncode`した文字列を
  `Box<String>`に保存する方式にすれば同様に回避できる。
- **Android実機/エミュレータでの動作確認は`flutter run`ではなく`flutter build apk` +
  `adb install -r` + `adb shell am start` + `adb logcat`のワンショット方式にする。**
  `flutter run`はターミナルにアタッチしたまま待機するプロセスのため、`run_in_background`で起動すると
  出力がバッファされず進捗が全く見えず、実質フリーズと区別がつかない。ビルド成果物を明示的に
  インストール・起動し、`dumpsys activity | grep mResumedActivity`や`logcat`のFATAL EXCEPTIONの
  有無で機械的に完了判定する方が非対話セッションに向く。
- **エミュレータのスクリーンショットは`adb exec-out screencap -p > file.png`をPowerShellの`>`で
  リダイレクトするとPNGヘッダが壊れる（BOM混入）。** `adb shell screencap -p /sdcard/x.png` →
  `adb pull /sdcard/x.png <ローカルパス>`の二段階にすると壊れず確実に読める。
- **文字の「見た目の中心」がずれているという指摘は、Flutterの`crossAxisAlignment.center`（論理的な
  テキストボックスの中心）と実際に描画される文字の黒み（インク）の中心が一致しないために起きることがある。**
  時計ウィジェットで「時刻と日付の中心がずれて気持ち悪い」と指摘された際、`Column`は正しくテキストの
  論理ボックス幅で中央揃えしていたが、末尾の全角括弧「（水）」のグリフに右側の余白（サイドベアリング）が
  大きく、見た目のインクだけがボックス内で左寄りになっていた。**確認方法**: `adb shell screencap`で
  スクリーンショットを取得し、PowerShellの`System.Drawing.Bitmap.GetPixel`で該当行を走査して
  非背景色ピクセルのmin/max Xを求めると、見た目の中心を数値で特定できる（同じ列の別ウィジェット
  （今回は`FishingCard`のCard境界）と比較して「真の中心」を確認するのが有効）。**対処**: 全角括弧
  「（〜）」を半角括弧「(〜)」に変えるだけで、この案件では中心のズレが約27pxから約1.5pxまで改善した
  （2560px幅のスクリーンショット上）。時刻側は数字の組み合わせ（特に細い「1」など）によって
  ±10px程度揺れるのは正常範囲として許容した。
- **`timezone`パッケージなしで「常に特定タイムゾーンの壁時計値」を安全に作るには、
  `DateTime.now().toUtc().add(Duration(hours: 9))`の結果からさらに`DateTime(y,m,d,h,m,s,ms,us)`で
  isUtc=falseの新しいDateTimeを組み直すとよい。**（2026-09-23、タイムゾーン設定機能で使用）
  `.toUtc().add(9h)`だけだとisUtc=trueのまま中身がJST値というねじれたオブジェクトになり、
  比較先が本物のUTC値だと`.difference()`や`.compareTo()`がズレる。年月日時分秒を読み直して
  isUtc=falseで再構築すれば、以後は端末のローカル扱いのDateTimeとして安全に運べる
  （`DateFormat`表示やy/m/d抽出だけに使う用途なら、この「ねじれ」を作らない設計にしておくのが安全）。
- **RSSのpubDateなど外部の絶対時刻は、パース直後に`.toLocal()`等で変換せずUTCのまま保持し、
  表示直前（Widgetのformat呼び出し側）でタイムゾーン変換するとキャッシュ往復に強い。**
  （2026-09-23）`toIso8601String()`でキャッシュに保存→`DateTime.parse()`で復元する際、UTC/local
  どちらのDateTimeで保存したかによって復元後の扱いが変わる。絶対時刻はUTCで一貫させ、表示側だけで
  ローカライズする設計にすると迷わない。
- **新しいPowerShellセッションはユーザー環境変数（`JAVA_HOME`/`ANDROID_HOME`等）を自動で
  引き継がないことがある。**（2026-09-23）`flutter doctor`は通っていたのに`flutter build apk`が
  「JAVA_HOME is not set」で失敗した。`[Environment]::GetEnvironmentVariable("JAVA_HOME","User")`で
  ユーザー環境変数自体は設定済みと確認できたので、`$env:JAVA_HOME = [Environment]::GetEnvironmentVariable(...)`
  のように該当プロセスへ明示的に読み込んでからビルドコマンドを実行すると解決した。非対話セッションで
  ビルドが環境変数絡みで失敗したら、まずこれを疑う。
- **fl_chartの`LineChart`は`ImplicitlyAnimatedWidget`で、位置引数`data`の後に`duration`/`curve`を
  名前付き引数で渡せる（`LineChart(LineChartData(...), duration: ..., curve: ...)`）。**
  データ（`spots`等）が変わると自動でなめらかに補間アニメーションする。Dartの構文上、位置引数を
  名前付き引数より先に書く必要がある点に注意（逆順だとコンパイルエラー）。
- **webp画像をPNGに変換したいとき、Windowsに変換ツール（ImageMagick/ffmpeg/Pillow）が無くても、
  Flutter同梱のDart SDK（`C:\src\flutter\bin\dart`）と`package:image`だけで足りる。**（2026-09-24、
  アプリアイコン更新時）System.Drawingの`Image.FromFile`はwebpを読めず「Out of Memory」という
  紛らわしいエラーになる。スクラッチディレクトリに最小限の`pubspec.yaml`（`image: ^4.5.4`のみ依存）と
  `bin/main.dart`（`img.decodeWebP(bytes)` → `img.encodePng(image)`）を置き`dart pub get` →
  `dart run bin/main.dart <in.webp> <out.png>`で変換できる。追加のシステムインストール不要。
- **GitBash(MSYS)から`adb`でリモートパス（`/sdcard/...`）を扱うと、パスがWindows形式に誤変換されて
  失敗することがある。**（2026-09-24）`MSYS_NO_PATHCONV=1`で全体を無効化すると今度はローカル側の
  保存先パスまで変換されず失敗する。**対処**: リモートパス側だけ`//sdcard/...`のように先頭を`//`にすると
  MSYSのパス変換を素通りできる（ローカル側の変換は有効なまま）。`adb pull //sdcard/x.png <ローカルパス>`
  の形が最も安定した。
- **`adb shell am force-stop`直後の`am start`でも、直前のセッションのUI状態（別画面や別アプリ）が
  スクリーンショットに映り込むことがある。** 原因未特定だが、`force-stop`は対象アプリだけでなく
  テスト中に開いた関連アプリ（例: url_launcherで開いたChrome）も一緒に`force-stop`してから
  再起動し、起動後数秒待ってからスクリーンショットを撮ると再現しなくなった。見た目がおかしい
  スクリーンショットを見たら、まず「本当に今起動したプロセスの画面か」を疑い、関連プロセスを
  すべて止めてから撮り直すとよい。

## Mistakes to Avoid 失敗と再発防止
<!-- 実際に踏んだ失敗と、次回の回避手順。重大なものは【重大】を先頭に付ける -->

- 【重大】`winget install`（MSI）は非対話セッションでUACの昇格待ちになり無期限に止まる。ポータブルZIP配布を使う
  （詳細は `docs/2026-10-04-開発環境の構築記録.md`）。

## Domain Knowledge 業務・仕事の事実
<!-- 調べて確定した仕様・振る舞い・制約。次回は調べ直さず前提にできるもの -->

- **このリポジトリ（`javis`）は`gocco-race`とは無関係の別プロジェクト。** 仕様書は
  `docs/2026-09-23-仕様書.pdf`（釣り・ニュース・時計ダッシュボードアプリ、Android卓上キオスク、Flutter製）。
- **開発環境の実体**: Flutter SDK `C:\src\flutter`（stable, shallow clone）／JDK 17(Temurin) `C:\src\jdk17`
  （ポータブルZIP）／Android SDK `%LOCALAPPDATA%\Android\sdk`（platform 37.1, build-tools 37.0.0,
  platform-tools, cmdline-tools;latest、ライセンス承諾済み）。PATH・`ANDROID_HOME`・`ANDROID_SDK_ROOT`・
  `JAVA_HOME`はユーザー環境変数に設定済み（新しいシェルなら自動で読める。既存のシェルでは手動export要）。
- **釣り・ニュース・時計ダッシュボード本体を実装済み（2026-09-23）。** 潮汐は気象庁の潮位表テキスト
  （観測地点コードは横浜=`QS`。似た名前の`YK`=京浜港は別地点なので混同注意、
  `lib/data/observation_points.dart`に地点一覧）、天気はOpen-Meteo（APIキー不要）、ニュースはRSS
  （既定: 4Gamer.net/ITmedia AI+/ITmedia NEWS）。状態管理はRiverpod（`legacy.dart`の
  StateNotifierProvider）、キャッシュはHive（JSON文字列保存、TypeAdapter不使用）、画面常時点灯は
  wakelock_plus（2026-09-29から時間帯指定、末尾の節参照）、バックグラウンド補助更新にworkmanager。実機的な検証は
  Androidエミュレータで`flutter build apk --debug`→`adb install`→起動確認まで実施し、時計・潮汐グラフ・
  天気・釣りやすさスコア（★表示＋内訳）・ニュース3タブ・設定画面すべてスクリーンショットで動作確認済み。
  「Lock Task Mode」（true kiosk化）はDevice Owner登録が要るため未実装（Open Questions参照）。
- **ITmediaのRSS利用規約は「アプリへの組み込みは個別相談」と明記されている。** 現状は個人利用の
  卓上キオスクアプリ（非公開・非配布）としてタイトル/配信元/時刻のみ表示し本文非複製の範囲で実装したが、
  もし将来配布・公開する場合は改めてITmediaに確認したほうがよい。
- **同じ記事がITmedia NEWSとITmedia AI+など複数のRSSフィードに重複掲載されることがある。**
  ジャンル別タブでは別カテゴリなので問題にならないが、全ジャンル合算表示（「総合」タブ）を作る際は
  タイトルで重複除去しないと同一記事が並んで見える（2026-09-23、ニュースに「総合」タブを追加した際に
  確認・対応済み。`DashboardState.allNewsSorted`でタイトル重複除去）。
- **タイムゾーン設定（`AppSettings.useFixedJst`、既定true）を追加済み（2026-09-23）。**
  全データソースが日本前提のため「常にJSTを使う/端末のシステム時刻に従う」のON/OFFトグルのみとし、
  IANAタイムゾーン一覧のような大掛かりな選択肢は採用しなかった（ユーザー承認済みの設計判断）。
  適用範囲は「表示・日付境界判定」（時計、最終更新表示、ニュースpubDate表示、潮汐の「今日」判定）に限定し、
  釣りやすさスコアの日の出/日の入り近接判定・月齢計算・各種キャッシュTTL判定は対象外（端末システム時計基準の
  ままで意図的に変更していない）。変換ロジックは`lib/util/app_clock.dart`の`appNow()`/`appLocalize()`に集約。
- **ニュースの自動更新は`DashboardController`の`Timer.periodic`（既定30分、設定画面で変更可）で
  実装済みで動いている。** 潮汐/天気と別のタイマーで独立して回している。動作確認は画面右上の
  「最終更新」表示と手動更新ボタン（リロードアイコン）で目視できる。
- **サイバーパンク装飾を追加済み（2026-09-23）。** ユーザーから「メインコンテンツ（フォント・枠）は
  控えめ、グラフや更新演出は派手めに」という指定があり、それに沿って役割分担した。配色定数は
  `lib/theme/cyberpunk_colors.dart`に集約。背景のネオングリッド＋走査線は`CyberpunkBackground`
  （`lib/widgets/cyberpunk_background.dart`、低輝度アニメーションで焼き付き対策も兼ねる）。
  データ更新時に対象カードへ一瞬ネオンの光る枠を重ねる演出は`UpdateFlashOverlay`
  （`lib/widgets/update_flash_overlay.dart`、`updateKey`に`lastUpdated`等のタイムスタンプを渡すと
  変化時のみ発火）で、`FishingCard`・`NewsFeed`に適用。潮汐グラフ（`tide_chart.dart`）は線に
  `shadow`でグローを付け、山/谷（満潮/干潮に近い極値）にマゼンタの発光マーカーを表示し、
  `LineChart`標準の`duration`/`curve`でデータ更新時になめらかに描き直る。釣りやすさ★バッジ
  （`fishing_score_badge.dart`）はスター数が変化した時だけ左から順に光りながらポップインする
  （`didUpdateWidget`で`stars`の変化を検知）。カード枠線は`main.dart`の`cardTheme`にネオンシアンの
  細いボーダーを一括設定するのみで、個々のウィジェット側は変更していない（控えめさの担保）。

- **釣り情報カードに水温を追加済み（2026-09-23）。** Open-Meteo Marine API
  （`https://marine-api.open-meteo.com/v1/marine`、`current=sea_surface_temperature`、
  APIキー不要）を使用。既存の天気取得（`WeatherService`）と同じ緯度経度で呼び出し、
  `WeatherData.seaSurfaceTemperatureC`（nullable）として統合した。取得失敗時は天気全体を
  失敗させずnullのまま（UI側は水温欄を省略するだけ）。内湾・河口部は衛星/モデルベースの
  外洋水温のため実際の釣り場水温とズレる可能性がある点をユーザーに説明済みで、許容の上で採用
  （ユーザー承認済みの設計判断）。
- **既存キャッシュのTTL内にモデルへ新フィールドを追加しても、実機で即座には反映確認できない。**
  （2026-09-23、水温追加時に遭遇）`WeatherService`は15分TTLでHiveにJSONキャッシュしており、
  新フィールド追加後に`adb install -r`しただけではアプリのHiveデータは保持されるため、
  古いキャッシュ（水温フィールドなし→nullable復元でnull）がそのまま使われて「効いていないように
  見える」。**確認方法**: `adb shell pm clear <applicationId>`でアプリデータを消してから再起動する
  とキャッシュが飛んで新規取得が走り、正しく検証できる。

## Open Questions 要調整
<!-- 未解決・保留・意図的にやらなかったこと。解決したら【解決済み】を付けて結論を残す -->

- 【解決済み】org/パッケージ名: ユーザー指定で`com.nadaryu.wall_jarvis`（プロジェクト名`wall_jarvis`）に確定
  （2026-09-23）。当初の仮称`fishing_dashboard`から変更済み。
- 【解決済み】対象釣り場・潮汐/天気/ニュースのデータソース選定（2026-09-23）。横浜（気象庁観測地点QS）、
  気象庁+Open-Meteo、RSS（4Gamer.net/ITmedia AI+/ITmedia NEWS）で実装済み。設定画面から地点・
  ニュース配信元は変更可能。詳細は Domain Knowledge 参照。
- Windows Desktop向けビルド用のVisual Studio C++コンポーネントは未導入（`flutter doctor`で警告）。
  Android優先のため後回しにした。デスクトップ版も出す判断になったら導入する。
- Android Lock Task Mode（画面ピン留め・誤操作防止の本格キオスク化）は未実装。Device Owner登録
  （`dpm set-device-owner`、通常は端末初期セットアップ時のみ可能）が前提になるため、対象タブレット確定後に
  改めて着手要否を判断する。現状は全画面表示＋wakelock_plusによる時間帯指定の常時点灯のみ対応。
- 【解決済み】ニュースの自動スクロール/切り替え表示（仕様書「検討」扱い）。2026-09-27に自動ページ送りとして実装済み
  （「ニュースの注目度順・自動ページ送り」の節参照）。
- 【解決済み】Android実機またはエミュレータでの`flutter run`確認（2026-09-23）。PC上のAndroidエミュレータで
  `wall_jarvis`（初期状態のカウンターアプリ）の起動を確認済み。詳細は Domain Knowledge 参照。

## PCエミュレータ環境（2026-09-23構築）

- AVD `wall_jarvis_tablet`（pixel_tablet, android-36）。起動は `emulator -avd wall_jarvis_tablet`、完了判定は
  `adb shell getprop sys.boot_completed` が `1`。導入手順と実測値は `docs/2026-09-29-エミュレータ環境.md` に切り出した。

## Consolidated Principles 統合した原則
<!-- 個別事例から抽出した、広く通用する判断基準 -->

- **規約ファイル より 過去の設計・引き継ぎ文書は弱い。** 食い違ったら規約に従い、文書側が古い旨を指摘する
- **リスクの非対称性で設計を選ぶ。** 既存の主要動線に触れる案と、追加だけで済む案があるなら後者
- **口頭・体感の「動いた」で完了にしない。** 機械的に判定できる根拠が揃って初めて完了
- **回帰を出したら、原因究明より先に戻す。** 壊れた変更の上に修正を積み増さない
- **「確認した」と言う前に、その確認方法が本当にその欠陥を検出できるかを自問する。**
- **一点で切り分かる質問を先に投げる。** 広く調べる前に、仮説を二分する観測を探す
- **着手前に述べた懸念は、完了報告の確認項目へそのまま繰り上げる。**
- **除外（ブラックリスト）より許可（ホワイトリスト）。** 除外条件は今あるものにしか効かず、後から追加されたものを素通しする
- **仮説は推測ではなく実データで潰す。** 命名や既定値からの推測ではなく、実際の値を列挙して読む
- **複数の症状は1つの原因の別の見え方かもしれない。** 別々に追う前に、共通の原因を1つ仮定して測りにいく
- **ユーザーの観察と自分の静的解析が食い違ったら、観察が正しい。**
- **「〜のままだから大丈夫」は、その値へ至る全経路を追ってから言う。**
- **対になった処理（開始と終了、取得と解放）で不具合が出たら、対称性の欠落をまず疑う。**

## 画面輝度の時間帯制御（2026-09-25）

- **輝度制御は`screen_brightness`の`setApplicationScreenBrightness`（アプリのウィンドウ単位）で実装済み。**
  2:00〜19:00は15%、それ以外は100%（`lib/util/brightness_schedule.dart`）。電源供給中のみ有効で、
  `battery_plus`の状態が`discharging`のときだけ`resetApplicationScreenBrightness`で本体設定に戻す
  （`unknown`/`connectedNotCharging`は据え置き給電とみなす、ユーザー承認済みの設計判断）。
  手動ボタン（ニュース欄ヘッダーの電球）の状態は次の切り替え時刻（2:00/19:00）まで保持。
- **輝度の実効値は`adb shell dumpsys window windows | grep -o 'sbrt=[0-9.]*'`で機械的に確認できる。**
  アプリがリセット中なら`sbrt`が出ない。電源状態は`dumpsys battery unplug` / `set status 3`（放電）/
  `reset`で模擬できる。時刻は`adb root`後に`settings put global auto_time 0`→
  `adb shell date -u MMDDhhmmYYYY.ss`で変更できる（検証後は`auto_time 1`に戻す）。
- **時計を巻き戻すと「期限付きの手動状態」が残り続ける罠がある。** 検証で端末時刻を過去に戻したら
  手動状態の期限（未来の2:00）より前になり自動に戻らなかった。切り替えた時刻（`_manualSince`）より
  前になったら解除する判定を追加して解消済み。
- **輝度の値は設定画面で変更可能（`AppSettings.dimBrightness`/`brightBrightness`、5%〜100%・5%刻み）。**
  （2026-09-25）スライダーのドラッグ中は`BrightnessController.preview`で表示中の側だけ即時反映し、
  指を離した時点で保存→`ref.listen(settingsProvider)`経由で`reapply`する。下限5%は画面が真っ黒で
  操作不能になるのを避けるため。定数`defaultDimBrightness`等は既定値としてのみ残している。

## ニュース記事のアプリ内WebView表示（2026-09-25）

- **ニュース記事のタップは外部ブラウザではなく、ニュースカード上に重ねたWebView（`webview_flutter`）で開く。**
  `lib/widgets/article_viewer.dart`。無操作で自動クローズする時間は`AppSettings.articleAutoCloseMinutes`
  （既定3分、設定画面で1/3/5/10/30分）。タイマーは`Listener.onPointerDown`・`setOnScrollPositionChange`・
  ページ遷移開始で延長する。戻るボタンは`PopScope`でページ履歴→パネルを閉じる、の順。http(s)以外の遷移は遮断。
- **`flutter pub add`で「Building with plugins requires symlink support」が出ても、Android向けの依存解決は
  完了している。** Windowsデスクトップ向けプラグインのsymlink作成の警告で、`pubspec.lock`に追記済みなら無視してよい。
- **GitBashでは`adb shell screencap -p /sdcard/x.png`のリモートパスも`//sdcard/...`にしないと誤変換で失敗する**
  （pullだけでなくshell側も同じ）。

## 雨雲レーダー（2026-09-26）

- **釣り情報カードの位置は`FishingRadarPanel`で「釣り情報⇔雨雲レーダー」を切り替える。**
  間隔は`AppSettings.panelSwitchIntervalMinutes`（既定10分、0=自動切り替えなし）。切り替え演出は
  `HoloFlipSwitcher`（Y軸3Dフリップ＋ネオン縁＋走査線）。透視係数を0.0014にしたら手前の辺が時計まで
  はみ出したので0.0006に下げた。フリップの途中を撮るには`adb shell "input tap ..; for i in 1 2 3; do screencap ..; done"`
  のように端末内で連続撮影する（PC側から撮ると間に合わない）。
- **気象庁ナウキャストは`jma.go.jp/bosai/jmatile/data/nowc/`（非公式、UTC時刻）。** 時刻一覧は
  `targetTimes_N1`（実況）/`N2`（予報）/`N3`（雷等）。降水は`{base}/none/{valid}/surf/hrpns/{z}/{x}/{y}.png`。
  **雷(liden)はPNGタイルではなく`.../surf/liden/data.geojson`**（タイルURLは全ズームで404）。
  **N2はN1より遅れて更新されることがあり**、「実況と同じbasetimeの予報だけ」に絞ると予報が0件になった
  → 予報は N2 の最新basetimeを使い、最新実況より後のvalidtimeだけ採る。
- **出典表記は設定画面→「データの出典・利用規約」（`AttributionScreen`）と、レーダー右下の小さな表記。**
  地理院タイルは色を反転・減光しているので「加工して作成」と明記している。

## Wikipediaの小ネタ表示（2026-09-27）

- **日本語版は Wikimedia の onthisday フィードが未対応（404 "language not yet supported"）。** 代わりに
  メインページの元データ `Wikipedia:今日は何の日 n月`（MediaWiki `action=parse&prop=wikitext`）の
  `== [[m月d日]] ==` 節を使う（1日10〜15件の厳選された短文）。秀逸な記事は
  `ja.wikipedia.org/api/rest_v1/feed/featured/YYYY/MM/DD` の `tfa.extract` の1文目。
  整形は `WikipediaService.cleanWikitext`。12か月分・4658件の実データで記法の残りがゼロになることを確認済み
  （`&nbsp;` だけ残っていたので実体参照も戻している）。
- **GitBashのcurlに日本語のクエリを直接渡すと文字コードが崩れて `missingtitle` になる。** アプリ（Dartの
  `Uri.https`）では問題ない。PC側で試すときは%エンコード済みのURLを使うか、Nodeの `fetch` +
  `encodeURIComponent` を使う。
- **表示は時計の下の `WikiTriviaTicker`（高さ28の1行固定）。** 収まる文は10秒表示、収まらない文は2.5秒止めてから
  60px/秒でスクロールし、末尾でも2.5秒止めてから次の項目へ進む（`SingleChildScrollView` + `animateTo`）。

## NASA APOD（時計の背景・全画面表示、2026-09-27）

- **APOD APIは日付指定なし＋`thumbs=true`で最新1件を取る。** `media_type`が`video`の日は`thumbnail_url`、
  サムネイルも無い日（`other`等）は前回の写真を使い続ける（`NasaApodService.parseResponse`）。`DEMO_KEY`の
  上限は実測で1時間10回（`X-Ratelimit-Limit`）なので、3時間TTLのHiveキャッシュ＋1時間ごとの確認にした。
  `hdurl`は4000px超・数MBになるので、全画面は`ResizeImage(policy: fit)`で画面の実ピクセルに縮めてデコードする。
- **`PageRouteBuilder`で直に出す画面は`Material`で包まないとTextが黄色の二重下線＋既定外フォントになる。**
  （全画面表示で踏んだ。Scaffoldを使わない画面では`ColoredBox`ではなく`Material(color: ...)`を使う）
- 時計の背景は`ApodClockBackground`（間隔・不透明度・全画面の自動復帰時間・APIキーは設定画面）。
  切り替えの実機確認は設定で「1分ごと」を選んで約65秒待てば撮れる。

## ニュースのジャンル追加（映画・アウトドア、ゲーム配信元の拡充、2026-09-27）

- **RSS 1.0（RDF）の記事は`pubDate`がなく`dc:date`（ISO 8601）で日時を持つ。** 4Gamer・GAME Watch・Game*Spark・
  cinemacafe が該当。以前は`pubDate`しか読まず日時なし→「総合」で常に最下段だった（4Gamerも実はこの状態だった）。
  `NewsService.parseFeed`で`dc:date`も読むよう修正済み。新しい配信元を足すときは`curl`で日付タグの種類を先に確認する。
- **既定の配信元は保存済み設定（Hive）に一覧ごと残るため、`defaultNewsSources`を変えても既存端末に反映されない。**
  `currentNewsSourcesVersion`と`newsSourcesAddedByVersion`（`lib/data/default_news_sources.dart`）で版を管理し、
  古い版の設定を読み込んだとき未登録の追加分だけ足す。既定の配信元を増やすときは版を上げて追加分を登録する。
- **RSSが取れない配信元（2026-09-27時点）**: ファミ通・電撃オンライン（404）、映画.com（403）、シネマトゥデイ（404）、hinata（404）。
- 「総合」は配信元ごとに新着15件まで（`DashboardState.allNewsPerSourceLimit`）、各ジャンルのタブは新着50件まで。

## ニュースの注目度順・自動ページ送り（2026-09-27）

- **注目度は「総合」タブだけ。はてなブックマーク件数API（`bookmark.hatenaapis.com/count/entries?url=..&url=..`、
  1回50件・キー不要）の件数を `件数/(経過時間h+2)^1.5` で割り引いて並べる**（`lib/util/news_ranking.dart`）。
  ITmediaは数十〜百件付くが、アウトドア・映画系はほぼ0件なので、注目度順の上位はITmedia中心になる。
- **自動ページ送りは `AppSettings.newsPageScrollMinutes`（既定3分、0=しない）。** 表示中タブを1画面分送り、
  末尾なら先頭へ戻る（「総合」はそのとき新着順⇔注目度順を切り替え）。タッチ・タブ切り替えでタイマーを数え直す。
- **行の高さが可変の `ListView` で末尾から `jumpTo(0)` すると、並べ直し時の位置補正で1行弱ずれて止まることがある。**
  実機で1件目のタイトルが切れた。次フレームで `offset != 0` なら再度 `jumpTo(0)` して解消した。

## 切り替え・更新を毎時の区切りに揃える（2026-09-27）

- **表示の切り替え（釣り⇔レーダー・宇宙写真・ニュースのページ送り）とデータ更新（潮汐/天気・ニュース）は、
  起動からの経過ではなく毎時0分を起点にした区切りで動く**（`lib/util/aligned_timer.dart`の`AlignedPeriodicTimer`、
  基準の時刻は`appNow()`）。手動操作の直後に区切りが来る場合（間隔の半分未満）は`deferIfSoon()`でその区切りを
  1回見送る（ユーザー指定）。間隔は60の約数だけにする方針で、潮汐・天気の45分は外し、保存済みの45は30に読み替えた。
- **キャッシュの有効期限と更新間隔を同じ長さにすると、区切りの時刻の更新で数ミリ秒足りずキャッシュが使われ、
  1回分の更新が飛ぶ。** 天気14分・ニュース9分（最短の間隔より1分短く）にした。
- 実機での確認は、端末の中で`date +%M%S`を見て区切りをまたぐまで待ち、2秒おきに`screencap`で撮る。
  12:10:07に起動して、12:15:00の直後に写真とページ送りが切り替わるのを確認した（以前の方式なら:07にずれる）。

## 雨雲レーダーの広域表示・県庁所在地マーク（2026-09-28）

- **同じ縮尺で2回再生するたびに「現状z8 ⇔ 地方全体」を切り替える。巻き戻しとフェードが重なるとせわしなく見えるため、最終コマで止めたまま0.5秒フェードし、0.6秒置いてから先頭に戻す**（ユーザー指定）。
  2つの縮尺の地図を重ねて両方とも常に読み込み、`AnimatedOpacity`で出し分ける（切り替え時の読み込み待ちをなくすため）。
  地方は観測地点に一番近い県庁所在地から決める（`nearestPrefecture`、`lib/data/prefectures.dart`。地方の範囲は手で決めた緯度経度、沖縄は九州と分けた）。
  広域は`WebMercator.fitZoom`で小数ズームを求め、整数ズームに切り捨てたタイルを拡大して並べる（4〜7の範囲に制限）。
  パネルが約2.4:1の横長なので、南北が収まる倍率になり、東西は隣の地方まで見える。
- **気象庁の降水タイル（hrpns）はz2〜z11まで取れる**（2026-09-28にcurlで実測）。
- 県庁所在地のマーク（マゼンタ）は`AppSettings.capitalMarkerPrefectures`（都道府県コードの集合、既定は全47）。
  観測地点のマークと12px未満の距離なら描かない。選ぶ画面は`CapitalMarkerSettingsScreen`（設定画面から開く別画面）。
- **このWindows環境では`python`がストアのスタブで動かない**（「Python」と出力されるだけで何もしない）。
  ファイルの一括書き換えはEditツールかsedを使う。
- **広域表示は縮小で淡色地図（pale）の海岸線が暗く細くなって見えにくい。** paleの海岸線は`99A2B7`前後の灰色の線だが、
  道路・文字も似た灰色なので色変換では海岸線だけを明るくできない。そこで広域表示だけ、地理院の白地図
  （`xyz/blank`、z5〜で取得可。海岸線と都道府県境だけが`#444444`で描かれている）を「白→透明、線→明るい灰色45%」の
  `ColorFilter`で雨雲の上に重ねた。海岸線と県境は同じ色なので、県境も一緒に明るくなる。好評だったので現状の縮尺（z8）にも同じ線を重ねている。

## 常時点灯の時間帯指定（2026-09-29）

- **常時点灯は起動時の固定をやめ、`KeepAwakeController`が毎分0秒に`AppSettings.keepAwakeSchedule`（平日・土・日で個別、終日/時間指定/なし）を
  判定して`WakelockPlus.toggle`する**（判定は`lib/util/keep_awake_schedule.dart`）。時間帯の外は本体の画面消灯設定に従う。開始が終了より遅いと翌日まで続き、
  はみ出し分も開始日の設定に従う。祝日は曜日どおり、開始時刻に画面を自動でつけ直すことはしない（どちらもユーザー承認済み）。既定は全曜日終日（従来どおり）。
- **確認は`adb shell dumpsys window windows | grep -c KEEP_SCREEN_ON`（0/1）で機械的にできる。** 端末時刻を飛ばすと、飛ばす前に予約した毎分タイマーが
  :00からずれて発火するため、切り替わりが最大1分遅れて見える（通常運用では起きない）。

## 地震情報（ニュース欄との切り替え、2026-09-30）

- **データはP2P地震情報 JSON API v2（`api.p2pquake.net/v2/history?codes=551`、キー不要・商用可・/historyは60回/分）。**
  1つの地震は「震度速報（震源-200、津波Checking）→震源情報（maxScale=-1）→各地の震度」と複数回届くので、`earthquake.time`で
  まとめ、項目ごとに有効値を持つ最新の発表から取る（`Earthquake.mergeReports`）。大きな地震の各地の震度は観測点が700件超・数百KBに
  なるため、毎分の確認は`limit=3`、30回に1回だけ`limit=60`で取り直す。仕様は`www.p2pquake.net/swagger-ui/specification.yaml`（WebFetchでは読めない）。
- **自動切り替えは震度3以上・発生30分以内で1地震1回、30分後にニュースへ戻す。手動で切り替えたら自動で戻す予定は取り消す**（ユーザー指定）。
  一覧は震度1以上をすべて表示。`--dart-define=QUAKE_ALERT_TEST=true`でビルドすると起動時に最新の地震で切り替わる（動作確認用）。
- **地理院の白地図（海岸線）はz5から。日本全体はz4相当になるので、z5のタイルを縮小して並べる**（z4の淡色地図は外国の地名も目立つ）。
- `Icons.earthquake`はこのFlutterに無い（`Icons.sensors`を使用）。切り替えるとNewsFeedは作り直され、タブ・スクロール位置は先頭に戻る。
- **地図の×印と同心円は、選んだ地震だけでなく直近24時間の地震すべてに同時に描く**（ユーザー指定、2026-09-30）。選んでいない地震は×印を小さく・円を淡くし、
  円の広がり始めを地震ごとにずらす。地図の範囲はそれらの震源がすべて収まるよう広げる。24時間より前は小さな点。同じ場所で繰り返した地震は重なって1つに見える。

## 台風情報（地震の地図に重ねて表示、2026-10-03）

- **データは気象庁ホームページの台風情報（`jma.go.jp/bosai/typhoon/data/`、キー不要・非公式）。** `targetTc.json`が発表中の一覧、
  `{id}/specifications.json`が実況と予報の数値（気圧・風速・大きさ・強さ）、`{id}/forecast.json`が図形（経路`track`、予報円`probabilityCircle`、
  強風域`galeWarningArea`=中心と半径、暴風域・暴風警戒域`stormWarningArea`=円弧`arc`と線分`line`）。半径はメートル、円弧の角度は北を0として時計回り。
  暴風警戒域は後の予報ほど手前の分を含むので最後の予報のものを使う。`targetTimes.json`は無い（404）。実データの見本は`test/fixtures/`。
- **切り替えは「日本付近の台風」だけ**（ユーザー指定）。現在位置か予報円（半径ぶん近く見積もる）が、県庁所在地か主な離島から500km以内に入る台風
  （`Typhoon.approachesJapan`）。熱帯低気圧と遠い台風は地図に描くだけ。間隔は`AppSettings.typhoonSwitchIntervalMinutes`（既定10分、0=しない）で、
  毎時0分起点の区切りごとにニュース⇔地図を交互に出す。地震で切り替えた30分間は地震を優先し、地図も台風に合わせて広げず
  地震だけのときの縮尺にする（`EarthquakePanel.quakeFocus`、ユーザー指定）。`--dart-define=TYPHOON_TEST=true`で遠い台風・熱帯低気圧も対象にできる。
- **`ColorFiltered`は中身が透明な場所にもかかる。** 白地図の線を明るくするフィルター（アルファを作り直す行列）は、タイルの無い場所を灰色に塗ってしまった
  （地図を東経157.5度より東へ広げて発覚）。フィルターの中に下地（白地図は白、淡色地図は海の色`#BED2FF`）を敷いて解消した。
- **エミュレータを強制終了すると、次の起動がクラッシュ報告の同意ダイアログで止まる**（adbに現れず、ログに`Showing crashdialog`）。
  `emulator -avd wall_jarvis_tablet -no-window`で起動すれば止まらず、`screencap`も使える。
- **地図に重ねる地震・台風の概要は、開いて8秒後に1行へたたむ（タップで開閉）**（2026-10-04、`AutoCollapseBox`。地図が隠れるというユーザー指摘）。
  表示直後と、選んだ地震・自動切り替え（`alertSeq`）・台風の顔ぶれが変わったときに開き直す。毎分のデータ更新では開き直さない。
  実機確認は`QUAKE_ALERT_TEST`+`TYPHOON_TEST`でビルドし、起動直後・15秒後・`input tap`後を`screencap`で撮る（起動に数秒かかるので8秒ちょうどでは撮れない）。
- **設定を読むウィジェットのテストは、`settingsProvider`を直接読まず小さなProvider（例: `typhoonSwitchIntervalProvider`）を挟むと、Hiveなしで差し替えられる。**
