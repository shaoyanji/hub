# hub

![hub: an index card fanning out to document spines and repository blocks](https://res.cloudinary.com/de1eajx01/image/upload/f_auto,q_auto,w_1200/assets/repos/hub)

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
does not answer keeps the committed copy and annotates the run, so a rate limit or
an outage cannot publish an empty section; only a source with no committed copy
renders as a link to itself. In CI the repo listing is read with the workflow
token, because the unauthenticated 60-per-hour limit is shared by every job on the
runner's address.

## Where a fact lives

| Fact | Home |
| :--- | :--- |
| title, description, mail, subpath, feed list, limits | `data/site.toml` |
| the five places the writing lives | `data/properties.toml` |
| the pages and their nav order | frontmatter in `content/*.md`; the home page is `site/pages/home.nix` |
| the chrome (header, nav slot, footer) | `site/layout.nix` |
| the stylesheet path | `site/theme.nix` |
| prose | `content/*.md` |
| style | `assets/css/style.css` |

Adding a property is one row in `data/properties.toml`. Adding a page is one
markdown file in `content/`: the path is the route, and its frontmatter supplies
the title, description and nav placement. `content/about.md` is a page that way
with no module at all. A page that needs markup of its own stays a module under
`site/pages/` and one line in `flake.nix` — that is why the home page is one.

## Checks

```bash
nix flake check
```

A static site cannot report a dead link at runtime, so the build gate does:

- `checks.site` — the site builds.
- `checks.links` — `nixstix.lib.site.checkLinks` walks every root-relative `href`
  in the output and fails on one that names no file, or one that leaves `/hub`.
- `checks.routes` — `/`, `/about/` and the stylesheet exist, their markers are the
  ones the pages declare, and `content/_index.md` is not routed (a `_` file is a
  partial, not a page).

`pages.yml` runs the same check after refreshing the live sources, so a broken
`/hub/` link fails the deploy instead of being published.

## Local build

```bash
python3 scripts/fetch-data.py   # refresh the two live sources
nix run .                       # serve the build under /hub on 127.0.0.1:8000
```

`/hub/` is the published subpath (`basePath` in `data/site.toml`); links are
prefixed with it so GitHub project Pages serves them. That is why the preview is
`nix run .` and not a plain `http.server -d result`: serving the output at `/`
would 404 its own absolute links. `PORT` overrides 8000.

Publishing is `.github/workflows/pages.yml` — fetch, gate, build, upload the built
directory as a Pages artifact, deploy it. Nothing built is committed, and no
branch is force-pushed: Pages serves the artifact (`build_type: workflow`).

The last step is a proof, not a formality: upload and deploy can both succeed while
the address still serves the previous build, so it compares the served
`index.html` to the built one (retrying while the CDN catches up) and fails the run
if they never match.

The store is **not** cached between runs, and that is measured rather than
assumed: with `cache-nix-action` keyed on `flake.lock`, a second run spent 28 s
unpacking a 169 MB archive, failed 2429 writes to root-owned store paths, and then
fetched and built the same derivations anyway — 65 s against 53 s without it. The
toolchain already comes from `cache.nixos.org`, and the site derivation changes
whenever the data does, so a store cache can only add time to this pipeline.
