# hub

An index of the writing, in one place: the five homes it lives in, the posts as
they are published, and the repositories behind them.

<https://shaoyanji.github.io/hub/>

## How it is built

[nixstix](https://github.com/shaoyanji/nixstix) — the site generator this repo
consumes as a flake input (`nixstix.lib.${system}.site.buildSite`). Pages are Nix
values, markdown is rendered as a build input of the site derivation, and the nav
is derived from the pages themselves.

The build reads no network. Two things are still live, so they are read *before*
the build by `scripts/fetch-data.py`:

- **recent writing** — the sources' RSS feeds (`[[feeds]]` in `data/site.toml`).
- **built** — `api.github.com/users/shaoyanji/repos`, sorted by last push, forks,
  archived repos and this repo filtered out.

The script writes `data/feeds.json` and `data/repos.json`; both are committed so a
fresh clone builds, and `pages.yml` refreshes them on every deploy. A source that
is down writes an empty list: its section renders as a link, never as a failed
build.

## Where a fact lives

| Fact | Home |
| :--- | :--- |
| title, description, mail, subpath, feed list, limits | `data/site.toml` |
| the five places the writing lives | `data/properties.toml` |
| the pages and their nav order | `site/pages/*.nix` |
| the chrome (header, nav slot, footer) | `site/layout.nix` |
| prose | `content/*.md` |
| style | `assets/css/style.css` |

Adding a property is one row in `data/properties.toml`. Adding a page is one file
in `site/pages/` plus one line in `flake.nix`; the nav picks it up from
`navLabel` / `navOrder`.

## Checks

```bash
nix flake check
```

A static site cannot report a dead link at runtime, so the build gate does:

- `checks.site` — the site builds.
- `checks.links` — `nixstix.lib.site.checkLinks` walks every root-relative `href`
  in the output and fails on one that names no file, or one that leaves `/hub`.
- `checks.routes` — `/`, `/about/` and the stylesheet exist, and their markers are
  the ones the pages declare.

`pages.yml` runs the same check after refreshing the live sources, so a broken
`/hub/` link fails the deploy instead of being published.

## Local build

```bash
python3 scripts/fetch-data.py   # refresh the two live sources
nix build .#site                # -> ./result
python3 -m http.server -d result 8000   # view it (links are /hub/…)
```

`/hub/` is the published subpath (`basePath` in `data/site.toml`); links are
prefixed with it so GitHub project Pages serves them.

Publishing is `.github/workflows/pages.yml` — fetch, build, upload the built
directory to the `gh-pages` branch. Nothing built is committed.
