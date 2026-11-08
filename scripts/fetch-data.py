#!/usr/bin/env python3
"""Refresh data/feeds.json and data/repos.json from the live sources.

The build itself is offline (a Nix build reads no network), so the net is read
here, once, before `nix build`. A source that is down writes an empty list: its
section renders as a link to the source, never as a failed build.
"""

import json
import pathlib
import sys
import tomllib
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
CONFIG = tomllib.loads((DATA / "site.toml").read_text())


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "hub-site/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read()


def day(text: str) -> str:
    try:
        return parsedate_to_datetime(text).astimezone(timezone.utc).strftime("%Y-%m-%d")
    except (TypeError, ValueError):
        return ""


def posts() -> list[dict]:
    limit = CONFIG.get("recentLimit", 8)
    out = []
    for feed in CONFIG.get("feeds", []):
        try:
            root = ET.fromstring(fetch(feed["url"]))
        except Exception as error:  # noqa: BLE001 - a dead source is not a failure
            print(f"feed {feed['url']} unreachable: {error}", file=sys.stderr)
            continue
        channel = root.find("channel")
        items = channel.findall("item") if channel is not None else root.findall(".//item")
        for item in items:
            title = (item.findtext("title") or "").strip()
            if not title:
                continue
            out.append(
                {
                    "title": title,
                    "link": (item.findtext("link") or feed["url"]).strip(),
                    "source": feed.get("label", feed.get("name", "")),
                    "dateText": day(item.findtext("pubDate") or ""),
                    "_sort": day(item.findtext("pubDate") or ""),
                }
            )
    out.sort(key=lambda item: item["_sort"], reverse=True)
    for item in out:
        del item["_sort"]
    return out[:limit]


def repos() -> list[dict]:
    user = CONFIG["projectsUser"]
    api = f"https://api.github.com/users/{user}/repos?sort=pushed&per_page=100"
    out = []
    try:
        for repo in json.loads(fetch(api)):
            if repo.get("fork") or repo.get("archived") or repo["name"] == "hub":
                continue
            out.append(
                {
                    "name": repo["name"],
                    "url": repo["html_url"],
                    "description": repo.get("description") or "",
                    "language": repo.get("language") or "",
                    "stars": repo.get("stargazers_count", 0),
                }
            )
    except Exception as error:  # noqa: BLE001
        print(f"github api unreachable: {error}", file=sys.stderr)
    return out[: CONFIG.get("projectsLimit", 9)]


def write(name: str, value) -> None:
    path = DATA / name
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    print(f"{path.relative_to(ROOT)}: {len(value)} entries")


if __name__ == "__main__":
    write("feeds.json", posts())
    write("repos.json", repos())
