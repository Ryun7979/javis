# Project Learnings

このファイルはセッションをまたいだ作業記憶です。各セッションの開始時に読み、作業の終わりに追記します。
1項目は 1〜3行。太字で主張を先頭に置き、根拠となった具体例と、次回の行動を続けます。

## Patterns That Work 効いたこと
<!-- 安く確実に目的を達した手順や調べ方。「次も同じ状況でそのまま使えるか」が基準 -->

- **Flutter SDKは`git clone -b stable --depth 1`で導入すると軽くて確実。** ZIP版の正確なバージョン番号URLを
  毎回調べる必要がなく、`C:\src\flutter`に置けばそのまま`flutter --version`が初回セットアップまで完結する。
- **Android cmdline-toolsのライセンス同意は`yes | sdkmanager --licenses`で非対話に通せる。**
  `sdkmanager`本体のパッケージインストールコマンドも同様に`yes | sdkmanager ...`で通る
  （対話プロンプト`Accept? (y/N)`にYが自動応答される）。
- **JDKは公式インストーラ（winget/MSI）ではなくAdoptiumのポータブルZIP配布を使うと管理者権限なしで導入できる。**
  `https://api.adoptium.net/v3/binary/latest/<version>/ga/windows/x64/jdk/hotspot/normal/eclipse`
  をcurlで取得しZip展開するだけで動く（`C:\src\jdk17`）。`JAVA_HOME`をユーザー環境変数に設定すれば
  `flutter doctor`が正しく検出する。
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
- **`adb shell am force-stop`直後の`am start`でも、直前のセッションのUI状態（別画面や別アプリ）が
  スクリーンショットに映り込むことがある。** 原因未特定だが、`force-stop`は対象アプリだけでなく
  テスト中に開いた関連アプリ（例: url_launcherで開いたChrome）も一緒に`force-stop`してから
  再起動し、起動後数秒待ってからスクリーンショットを撮ると再現しなくなった。見た目がおかしい
  スクリーンショットを見たら、まず「本当に今起動したプロセスの画面か」を疑い、関連プロセスを
  すべて止めてから撮り直すとよい。

## Mistakes to Avoid 失敗と再発防止
<!-- 実際に踏んだ失敗と、次回の回避手順。重大なものは【重大】を先頭に付ける -->

- **【重大】`winget install`でJDK（MSI版）を入れようとすると、非対話セッションではUACの昇格待ちで
  無期限にハングする。** `msiexec`が管理者権限を要求し、承認できる人間がいないため止まったまま進まない
  （`Get-Process`で見ると`msiexec`のプロパティが読めなくなり、別ユーザーコンテキストに昇格している状態が
  確認できた）。**次回の回避策**: Windowsの非対話セッションで開発ツールを入れるときは、最初から
  管理者権限が要らないポータブルZIP/tar配布を探す。winget/MSIをどうしても使う場合は、数分で進捗が
  無ければプロセスを`Stop-Process -Force`で切って別手段に切り替える判断を早めにする。

## Domain Knowledge 業務・仕事の事実
<!-- 調べて確定した仕様・振る舞い・制約。次回は調べ直さず前提にできるもの -->

- **このリポジトリ（`javis`）は`gocco-race`とは無関係の別プロジェクト。** 仕様書は
  `docs/2026-09-23-仕様書.pdf`（釣り・ニュース・時計ダッシュボードアプリ、Android卓上キオスク、Flutter製）。
- **開発環境の実体**: Flutter SDK `C:\src\flutter`（stable, shallow clone）／JDK 17(Temurin) `C:\src\jdk17`
  （ポータブルZIP）／Android SDK `%LOCALAPPDATA%\Android\sdk`（platform 37.1, build-tools 37.0.0,
  platform-tools, cmdline-tools;latest、ライセンス承諾済み）。PATH・`ANDROID_HOME`・`ANDROID_SDK_ROOT`・
  `JAVA_HOME`はユーザー環境変数に設定済み（新しいシェルなら自動で読める。既存のシェルでは手動export要）。
- **`flutter create --org com.nadaryu --project-name wall_jarvis .`でリポジトリ直下に雛形を作成済み。**
  パッケージ名は当初`fishing_dashboard`という仮称で作ったが、ユーザー指定により`wall_jarvis`へ変更
  （applicationId: `com.nadaryu.wall_jarvis`）。名前変更は生成物を全削除してから`flutter create`を
  再実行する方式で対応した（コミット前だったので安全に一括作り直しができた）。
  `flutter analyze`・`flutter test`とも初期状態でPASS。まだ実機/エミュレータでの起動確認はしていない。
- **釣り・ニュース・時計ダッシュボード本体を実装済み（2026-09-23）。** 潮汐は気象庁の潮位表テキスト
  （観測地点コードは横浜=`QS`。似た名前の`YK`=京浜港は別地点なので混同注意、
  `lib/data/observation_points.dart`に地点一覧）、天気はOpen-Meteo（APIキー不要）、ニュースはRSS
  （既定: 4Gamer.net/ITmedia AI+/ITmedia NEWS）。状態管理はRiverpod（`legacy.dart`の
  StateNotifierProvider）、キャッシュはHive（JSON文字列保存、TypeAdapter不使用）、画面常時点灯は
  wakelock_plus、バックグラウンド補助更新にworkmanager。実機的な検証は
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
  改めて着手要否を判断する。現状は全画面表示＋wakelock_plusによる常時点灯のみ対応。
- ニュースの自動スクロール/切り替え表示オプション（仕様書「検討」扱い）は未実装。タブ切り替え＋
  縦スクロールリストのみ。常時無人稼働時に定期スクロールが欲しくなったら追加検討。
- 【解決済み】Android実機またはエミュレータでの`flutter run`確認（2026-09-23）。PC上のAndroidエミュレータで
  `wall_jarvis`（初期状態のカウンターアプリ）の起動を確認済み。詳細は Domain Knowledge 参照。

## PCエミュレータ環境（2026-09-23構築）

- **導入パッケージ**: `emulator`（37.1.11）、`system-images;android-36;google_apis;x86_64`（API 37.1向けの
  エミュレータ用システムイメージは本日時点で未配布のため、次点の android-36 を採用）。
  `sdkmanager <pkg1> <pkg2>` にYes応答をパイプすれば非対話でインストールできる（既存パターンの応用）。
- **AVD**: 名前`wall_jarvis_tablet`、デバイスプロファイル`pixel_tablet`（卓上キオスクのタブレット用途に近い）。
  `avdmanager create avd -n <name> -k <system-image> -d pixel_tablet` で作成。
  実行時に`Could not load devices from ...\system-images\...\devices.xml`という警告が出るが無害
  （`avdmanager list avd`で正常に一覧に出る）。次回同じ警告が出ても慌てず一覧で確認すればよい。
- **アクセラレーション**: Windows Hypervisor Platform (WHPX) が有効で`emulator -accel-check`もOK。
  追加設定不要だった。
- **起動確認**: `emulator -avd wall_jarvis_tablet` → `adb shell getprop sys.boot_completed`が`1`になるまで
  待てば起動完了が機械的に判定できる。その後`flutter run -d emulator-5554`でビルド→インストール→起動まで成功、
  `flutter analyze`/`flutter test`もPASSのまま（初回Gradleビルドは約5分、Android SDK Build-Tools 36と
  Platform 36の追加ダウンロードが自動発生した）。
- **次回のエミュレータ起動**: SDK類は導入済みなので、`emulator -avd wall_jarvis_tablet`だけで起動できる
  （PATHに`%LOCALAPPDATA%\Android\sdk\emulator`を通しておくと`emulator`コマンドが直接使える）。

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
