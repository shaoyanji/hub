# hub

An index of the writing, in one place: the five homes it lives in, the posts as
they are published, and the repositories behind them.

<https://shaoyanji.github.io/hub/>

## How it is built

Hugo, no theme, no JavaScript. Two things are read at build time rather than
kept by hand, because a hand-kept list is wrong within a week:

- **recent writing** — the sources' RSS feeds (`params.feeds` in `hugo.toml`).
- **built** — `api.github.com/users/shaoyanji/repos`, sorted by last push,
  forks and this repository filtered out.

Both are wrapped in `try`: a source that is down renders as its own empty
section with a link, never as a failed build.

## Adding a property

One row in `data/properties.yaml`. The page renders the list; there is no
second place naming a host.

## Local build

```bash
nix shell nixpkgs#hugo -c hugo server
```

Publishing is the workflow in `.github/workflows/pages.yml` — build, upload the
artifact, deploy to Pages. Nothing built is committed; `public/` is ignored.
