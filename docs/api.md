# 受信機の API

アプリは受信機（ラズパイなど）から、次の JSON を HTTP の GET で読みます。
受信機をこの形に合わせれば、アプリは変えずに実機のデータを表示できます。

[receiver/demo_server.py](../receiver/demo_server.py) が同じ形を作り物のデータで返すので、実装の見本になります。

- 時刻は、タイムゾーン付きの ISO 8601（例 `2026-11-06T21:00:00+09:00`）
- 文字コードは UTF-8
- 見つからないときは 404

## GET /api/status

接続の確認に使います。

```json
{ "name": "牛舎の受信機", "time": "2026-11-06T21:00:00+09:00" }
```

## GET /api/soil

```json
{
  "sensors": [
    {
      "id": "soil-1",
      "name": "畑A",
      "location": "ハウス東",
      "moisture": 42.5,
      "temperature": 21.3,
      "battery": 86,
      "updated_at": "2026-11-06T20:58:00+09:00",
      "dry_below": 30,
      "wet_above": 60,
      "cold_below": 10,
      "hot_above": 30
    }
  ]
}
```

| 項目 | 意味 |
| --- | --- |
| `moisture` | 土の水分（%） |
| `temperature` | 土の温度（℃）。測らないセンサーは `null` |
| `battery` | 電池の残り（%） |
| `dry_below` / `wet_above` | 水分がこれより下は乾燥、上は過湿 |
| `cold_below` / `hot_above` | 温度がこれより下は低温、上は高温 |

`updated_at` が1時間より古いと、アプリは「通信なし」と表示します。

## GET /api/soil/{id}?hours=168

```json
{
  "sensor": { "id": "soil-1", "...": "/api/soil の1件と同じ" },
  "history": [
    { "time": "2026-11-06T20:00:00+09:00", "moisture": 42.9, "temperature": 21.0 }
  ]
}
```

`history` は古い順です。`hours` は過去何時間分か（アプリは 24 と 168 を使います）。

## GET /api/cows

```json
{
  "cows": [
    {
      "id": "102",
      "name": "モモ",
      "current": "rest",
      "battery": 78,
      "updated_at": "2026-11-06T20:58:00+09:00",
      "last_24h": { "rest": 492, "eat": 305, "walk": 277, "ruminate": 366 },
      "usual_ruminate": 388,
      "flag": "発情の候補"
    }
  ]
}
```

| 項目 | 意味 |
| --- | --- |
| `current` | 今の行動。`rest` 休息、`eat` 採食、`walk` 歩行、`ruminate` 反すう |
| `last_24h` | 過去24時間の行動ごとの合計（分） |
| `usual_ruminate` | いつもの1日の反すう時間（分） |
| `flag` | 人が確認するための知らせ。なければ `null` |

## GET /api/cows/{id}

```json
{
  "cow": { "id": "102", "...": "/api/cows の1件と同じ" },
  "hours": [
    {
      "time": "2026-11-06T20:00:00+09:00",
      "rest": 30, "eat": 10, "walk": 5, "ruminate": 15,
      "usual_active": 15
    }
  ]
}
```

`hours` は過去24時間分で、古い順です。`rest`〜`ruminate` はその1時間の分数です。
`usual_active` は、同じ時間帯のいつもの活動量（採食＋歩行の分数）です。

## GET /api/alerts

```json
{
  "alerts": [
    {
      "level": "warning",
      "kind": "soil",
      "target_id": "soil-2",
      "title": "畑B: 乾燥",
      "message": "ハウス西の水分は 24.2% です",
      "time": "2026-11-06T20:56:00+09:00"
    }
  ]
}
```

`level` は `warning` か `critical`、`kind` は `soil`（水分）、`temperature`（土の温度）、`cow` のどれかです。`target_id` のセンサーや牛の画面に移動できます。
