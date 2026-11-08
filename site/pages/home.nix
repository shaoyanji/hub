{ lib, site, basePath }:
let
  inherit (lib.dsl) el text;
  inherit (lib) markdown data;

  layout = import ../layout.nix { inherit lib site basePath; };

  props = (data.fromTOMLFile ../../data/properties.toml).properties;
  posts = data.fromJSONFile ../../data/feeds.json;
  repos = data.fromJSONFile ../../data/repos.json;

  host =
    url:
    let
      matched = builtins.match "https?://([^/]+).*" url;
    in
    if matched == null then "" else builtins.head matched;

  card =
    p:
    el "li" { class = "card"; } [
      (el "a" { href = p.url; } [
        (el "span" { class = "card-name"; } [ (text p.name) ])
        (el "span" { class = "card-kind"; } [ (text p.kind) ])
      ])
      (el "p" { } [ (text p.blurb) ])
      (el "span" { class = "host"; } [ (text (host p.url)) ])
    ];

  writing =
    if posts == [ ]
    then
      el "p" { class = "muted"; } [
        (text "The feeds did not answer at build time. ")
        (el "a" { href = "https://jisifu.mataroa.blog"; } [ (text "mataroa") ])
        (text " has them.")
      ]
    else
      el "ul" { class = "list"; } (
        map (p:
          el "li" { } [
            (el "a" { href = p.link; } [ (text p.title) ])
            (el "span" { class = "meta"; } [ (text "${p.dateText} · ${p.source}") ])
          ])
        posts
      );

  projects =
    if repos == [ ]
    then
      el "p" { class = "muted"; } [
        (text "The GitHub API did not answer at build time — see ")
        (el "a" { href = "https://github.com/${site.projectsUser}"; } [ (text "github.com/${site.projectsUser}") ])
        (text ".")
      ]
    else
      el "ul" { class = "list projects-list"; } (
        map (r:
          el "li" { } [
            (el "a" { href = r.url; } [ (text r.name) ])
            (el "span" { class = "desc"; } (if r.description == "" then [ ] else [ (text r.description) ]))
            (el "span" { class = "meta"; } [
              (text (
                if r.stars > 0
                then "${r.language} · ${toString r.stars}★"
                else r.language
              ))
            ])
          ])
        repos
      );
in
layout {
  title = site.title;
  route = "index.html";
  description = site.description;
  navLabel = "home";
  navOrder = 10;
  inner = [
    (el "section" { class = "intro"; } [
      (lib.dsl.markdown (markdown.fromFile ../../content/_index.md))
    ])
    (el "section" { class = "properties"; } [
      (el "h2" { } [ (text "where it lives") ])
      (el "ul" { class = "cards"; } (map card props))
    ])
    (el "section" { class = "writing"; } [
      (el "h2" { } [ (text "recent writing") ])
      writing
    ])
    (el "section" { class = "projects"; } [
      (el "h2" { } [ (text "built") ])
      projects
    ])
  ];
}
