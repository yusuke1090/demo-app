#!/usr/bin/env python3
"""農場モニターの受信機 API を、作り物のデータで動かす開発用サーバー。

アプリと受信機のつなぎ込みを確かめるためのもの。実機のラズパイでは、
同じ形の JSON を SQLite の記録から返すようにする（docs/api.md）。

    python3 receiver/demo_server.py --port 8080
"""

import argparse
import json
import math
import random
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

BEHAVIORS = ("rest", "eat", "walk", "ruminate")

SOIL = [
    # id, 名前, 場所, 水分, 温度, 電池, 何分前, 乾燥, 過湿
    ("soil-1", "畑A", "ハウス東", 42.5, 21.3, 86, 2, 30, 60),
    ("soil-2", "畑B", "ハウス西", 24.2, 20.8, 71, 4, 30, 60),
    ("soil-3", "畑C", "露地 南側", 55.8, 17.6, 64, 7, 30, 60),
    ("soil-4", "牧草地", "北の区画", 38.0, None, 12, 180, 25, 55),
]

COWS = [
    # id, 名前, 乱数の種, 電池, 知らせ
    ("101", "ハナ", 1, 92, None),
    ("102", "モモ", 2, 78, "発情の候補"),
    ("103", "サクラ", 3, 64, "体調確認の候補"),
    ("104", "ユキ", 4, 17, None),
]


def iso(t):
    return t.astimezone().isoformat(timespec="seconds")


def soil_sensor(spec, now):
    sid, name, location, moisture, temp, battery, ago, dry, wet = spec
    return {
        "id": sid,
        "name": name,
        "location": location,
        "moisture": moisture,
        "temperature": temp,
        "battery": battery,
        "updated_at": iso(now - timedelta(minutes=ago)),
        "dry_below": dry,
        "wet_above": wet,
    }


def soil_history(spec, now, hours):
    updated = now - timedelta(minutes=spec[6])
    moisture = spec[3]
    points = []
    for t in range(hours, -1, -1):
        value = moisture if t == 0 else moisture + (t % 72) * 0.2 + 0.6 * math.sin(t * 0.7 + moisture)
        points.append({"time": iso(updated - timedelta(hours=t)), "moisture": round(value, 1)})
    return points


def usual(hour):
    if hour < 6:
        rest, eat, walk, ruminate = 40, 1, 1, 18
    elif hour < 10:
        rest, eat, walk, ruminate = 12, 30, 8, 10
    elif hour < 16:
        rest, eat, walk, ruminate = 25, 10, 5, 20
    elif hour < 21:
        rest, eat, walk, ruminate = 12, 28, 8, 12
    else:
        rest, eat, walk, ruminate = 35, 3, 2, 20
    return {"rest": rest, "eat": eat, "walk": walk, "ruminate": ruminate}


def cow_hour(spec, time, hours_ago):
    base = usual(time.hour)
    rng = random.Random(spec[2] * 1000003 + int(time.timestamp()) // 3600)
    values = {b: base[b] * (0.85 + rng.random() * 0.3) for b in BEHAVIORS}
    if spec[4] == "発情の候補" and hours_ago <= 10:
        values["walk"] = values["walk"] * 3.2 + 6
        values["rest"] *= 0.6
    if spec[4] == "体調確認の候補":
        values["ruminate"] *= 0.45
        values["eat"] *= 0.7
    total = sum(values.values())
    row = {b: round(values[b] / total * 60) for b in ("eat", "walk", "ruminate")}
    row["rest"] = 60 - sum(row.values())
    row["time"] = iso(time)
    row["usual_active"] = base["eat"] + base["walk"]
    return row


def cow_detail(spec, now):
    this_hour = now.replace(minute=0, second=0, microsecond=0)
    hours = [cow_hour(spec, this_hour - timedelta(hours=i), i) for i in range(23, -1, -1)]
    cow = {
        "id": spec[0],
        "name": spec[1],
        "current": max(BEHAVIORS, key=lambda b: hours[-1][b]),
        "battery": spec[3],
        "updated_at": iso(now - timedelta(minutes=spec[2])),
        "last_24h": {b: sum(h[b] for h in hours) for b in BEHAVIORS},
        "usual_ruminate": sum(usual(h)["ruminate"] for h in range(24)),
        "flag": spec[4],
    }
    return {"cow": cow, "hours": hours}


def alerts(now):
    result = []
    for spec in COWS:
        cow = cow_detail(spec, now)["cow"]
        title = f"{cow['id']} {cow['name']}"
        if cow["flag"]:
            low = cow["flag"] == "体調確認の候補"
            result.append({
                "level": "critical" if low else "warning",
                "kind": "cow",
                "target_id": cow["id"],
                "title": f"{title}: {cow['flag']}",
                "message": "反すうの時間がいつもより減っています" if low else "歩く時間がいつもより増えています",
                "time": cow["updated_at"],
            })
        if cow["battery"] < 20:
            result.append({
                "level": "warning",
                "kind": "cow",
                "target_id": cow["id"],
                "title": f"{title}: 電池が少なくなっています",
                "message": f"首輪の電池の残りは {cow['battery']}% です",
                "time": cow["updated_at"],
            })
    for spec in SOIL:
        sensor = soil_sensor(spec, now)
        if spec[6] > 60:
            title, message = "通信なし", f"{sensor['location']}のセンサーからデータが届いていません"
        elif sensor["moisture"] < sensor["dry_below"]:
            title, message = "乾燥", f"{sensor['location']}の水分は {sensor['moisture']}% です"
        elif sensor["moisture"] > sensor["wet_above"]:
            title, message = "過湿", f"{sensor['location']}の水分は {sensor['moisture']}% です"
        else:
            continue
        result.append({
            "level": "warning",
            "kind": "soil",
            "target_id": sensor["id"],
            "title": f"{sensor['name']}: {title}",
            "message": message,
            "time": sensor["updated_at"],
        })
    return result


def route(path, query, now):
    """パスに応じた応答を返す。見つからなければ None。"""
    parts = [unquote(p) for p in path.strip("/").split("/")]
    if parts[0] != "api":
        return None
    rest = parts[1:]
    if rest == ["status"]:
        return {"name": "デモ受信機", "time": iso(now)}
    if rest == ["soil"]:
        return {"sensors": [soil_sensor(s, now) for s in SOIL]}
    if rest == ["cows"]:
        return {"cows": [cow_detail(c, now)["cow"] for c in COWS]}
    if rest == ["alerts"]:
        return {"alerts": alerts(now)}
    if len(rest) == 2 and rest[0] == "soil":
        spec = next((s for s in SOIL if s[0] == rest[1]), None)
        if spec is None:
            return None
        try:
            hours = int(query.get("hours", ["168"])[0])
        except ValueError:
            hours = 168
        hours = max(1, min(hours, 24 * 31))
        return {"sensor": soil_sensor(spec, now), "history": soil_history(spec, now, hours)}
    if len(rest) == 2 and rest[0] == "cows":
        spec = next((c for c in COWS if c[0] == rest[1]), None)
        return None if spec is None else cow_detail(spec, now)
    return None


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        body = route(url.path, parse_qs(url.query), datetime.now())
        status = 200 if body is not None else 404
        data = json.dumps(body if body is not None else {"error": "not found"}, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"http://{args.host}:{server.server_port} で待ち受けています（Ctrl+C で終了）", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
