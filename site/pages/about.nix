{ lib, site, basePath }:
let
  layout = import ../layout.nix { inherit lib site basePath; };
in
layout {
  title = "About";
  route = "about/index.html";
  description = "Who writes here, and where the rest of it is.";
  navLabel = "about";
  navOrder = 20;
  inner = [
    (lib.dsl.el "article" { } [
      (lib.dsl.el "h1" { } [ (lib.dsl.text "About") ])
      (lib.dsl.markdown (lib.markdown.fromFile ../../content/about.md))
    ])
  ];
}
