# デモアプリ

土の水分や牛の行動など、自作のセンサーの結果をスマホで確認する Android アプリ（Flutter）。

自作の開発物の結果をまとめて試すためのアプリです。使えそうなものは、ここから独立したアプリにしていきます。

**[APK をダウンロード](https://github.com/yusuke1090/demo-app/releases/latest/download/demo-app.apk)**

![ホーム](docs/screenshots/home.png) ![土の水分](docs/screenshots/soil-detail.png) ![土の温度](docs/screenshots/temperature-detail.png) ![牛の行動](docs/screenshots/cow-detail.png)

- **ホーム**: 全体の様子と、確認することの一覧
- **水分**: センサーごとの土の水分と、24時間・7日間の記録
- **温度**: センサーごとの土の温度と、24時間・7日間の記録
- **牛**: 今の行動、過去24時間の行動、いつもの活動量との比較、発情・体調の候補
- **設定**: デモデータと受信機の切り替え

発情や体調の候補は診断ではなく、人が確認するための知らせです。

今はデモデータで動きます。実機の受信機はまだなく、[デモ用のサーバー](receiver/demo_server.py)で接続を確かめられます。

## スマホに入れる

1. Android のスマホで上の「APK をダウンロード」を開く（リポジトリが非公開の間は、GitHub にログインしたブラウザで開く）
2. ダウンロードした `demo-app.apk` を開く
3. 「提供元不明のアプリ」の許可を求められたら、ブラウザに許可する

更新するときも、同じ手順で上書きできます。データはアプリを消さない限り残ります。

## しくみ

```text
ピコ（首輪・土のセンサー）── 電波 ──→ 受信機（ラズパイ）── Wi-Fi ──→ このアプリ
```

アプリは受信機の HTTP API を読むだけです。形は [docs/api.md](docs/api.md) にまとめてあります。
全体の考え方は、[Pico Studio のガイド 13章](https://github.com/yusuke1090/pico-studio/blob/main/guide/13-development.md)にあります。

## 受信機につないで試す

PC でデモ用のサーバーを動かします。Python だけで動きます。

```sh
python3 receiver/demo_server.py --port 8080
```

スマホを同じ Wi-Fi につないで、アプリの「設定」に PC の IP アドレスとポート（例 `192.168.3.123:8080`）を入れて「接続する」を押します。
つながらないときは、PC のファイアウォールで 8080 番が閉じていないか確かめます。

## 開発

`main` にプッシュすると、GitHub Actions が解析とテストをして、APK を作り直します。Android SDK や Mac は手元になくても開発できます。

手元で確かめるときは [Flutter](https://docs.flutter.dev/install) を入れて、次を実行します。

```sh
flutter pub get
flutter analyze
flutter test
```

| 場所 | 中身 |
| --- | --- |
| `lib/data/` | データの取得元。デモと受信機を `DataSource` で切り替える |
| `lib/screens/` | 画面 |
| `lib/widgets/` | グラフと共通の部品 |
| `receiver/` | 開発用の受信機 |

画面の画像は `SCREENSHOTS=1 flutter test --update-goldens test/screenshots_test.dart` で作り直せます（Noto Sans CJK が必要）。

### 署名の鍵

APK は、Actions の secret（`FARM_KEYSTORE_BASE64`、`FARM_KEYSTORE_PASSWORD`）の鍵で署名します。鍵が変わると上書き更新できなくなるので、作り直さないでください。
控えは手元の `~/.config/farm-monitor/` にあります（リポジトリには入れていません）。

### iPhone 版

同じコードから作れますが、`flutter create --platforms ios .` で設定を足して、Mac か macOS の CI でビルドし、Apple Developer Program（有料）で署名する必要があります。
