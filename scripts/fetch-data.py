#!/usr/bin/env python3
"""Refresh data/feeds.json and data/repos.json from the live sources.

The build itself is offline (a Nix build reads no network), so the net is read
here, once, before `nix build`. A source that is down keeps the committed copy
of its file: an empty list deployed as a section reads like a regression, and a
stale one does not. A degraded refresh is reported as a CI warning.
"""

import json
import os
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

TOKEN = os.environ.get("GITHUB_TOKEN", "")


def note(message: str) -> None:
    """A degraded refresh is visible, not just a line in a log nobody reads."""
    print(message, file=sys.stderr)
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::warning::{message}")


def fetch(url: str, headers: dict[str, str] | None = None) -> bytes:
    merged = {"User-Agent": "hub-site/1.0"}
    merged.update(headers or {})
    request = urllib.request.Request(url, headers=merged)
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read()


def api(url: str) -> bytes:
    # Only api.github.com ever sees the token. Unauthenticated, the repo listing
    # shares a 60-per-hour limit with every other job on the runner's address,
    # and a rate-limited answer is exactly the case the fallback below hides.
    headers = {"Accept": "application/vnd.github+json"}
    if TOKEN:
        headers["Authorization"] = f"Bearer {TOKEN}"
    return fetch(url, headers)


def day(text: str) -> str:
    try:
        return parsedate_to_datetime(text).astimezone(timezone.utc).strftime("%Y-%m-%d")
    except (TypeError, ValueError):
        return ""


def posts() -> tuple[list[dict], bool]:
    limit = CONFIG.get("recentLimit", 8)
    out = []
    answered = False
    for feed in CONFIG.get("feeds", []):
        try:
            root = ET.fromstring(fetch(feed["url"]))
        except Exception as error:  # noqa: BLE001 - a dead source is not a failure
            note(f"feed {feed['url']} unreachable: {error}")
            continue
        answered = True
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
    return out[:limit], answered


def repos() -> tuple[list[dict], bool]:
    user = CONFIG["projectsUser"]
    url = f"https://api.github.com/users/{user}/repos?sort=pushed&per_page=100"
    out = []
    try:
        listing = json.loads(api(url))
    except Exception as error:  # noqa: BLE001
        note(f"github api unreachable: {error}")
        return out, False
    for repo in listing:
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
    return out[: CONFIG.get("projectsLimit", 9)], True


def write(name: str, value, answered: bool) -> None:
    path = DATA / name
    if not answered:
        try:
            previous = json.loads(path.read_text())
        except (OSError, ValueError):
            previous = None
        if previous:
            note(f"{path.relative_to(ROOT)}: source did not answer, kept the last good copy ({len(previous)} entries)")
            return
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    print(f"{path.relative_to(ROOT)}: {len(value)} entries")


if __name__ == "__main__":
    for name, (value, answered) in (("feeds.json", posts()), ("repos.json", repos())):
        write(name, value, answered)
