{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixstix.url = "github:shaoyanji/nixstix";
  };

  outputs = { self, nixpkgs, nixstix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forSystem = system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = nixstix.lib.${system};
          config = lib.data.fromTOMLFile ./data/site.toml;
          pageArgs = {
            inherit lib;
            basePath = config.basePath;
            site = config;
          };
          # The chrome, and the stylesheet path it loads, for the content step.
          chrome = import ./site/layout.nix pageArgs;
          theme = import ./site/theme.nix;

          # The content step wraps a markdown body in a page of its own, so the
          # layout hands back the body of the chrome page it builds.
          contentLayout = { page, content, ... }:
            (chrome {
              inherit (page) title route description navLabel navOrder;
              inner = [ (lib.dsl.el "article" { } [ content ]) ];
            }).body;

          built =
            lib.site.buildSite {
              name = "hub";
              basePath = config.basePath;
              pages = [ (import ./site/pages/home.nix pageArgs) ]
                ++ lib.content.pages {
                  dir = ./content;
                  site = config;
                  layout = contentLayout;
                  head = [ (lib.dsl.stylesheet theme.stylesheetHref) ];
                };
              assets = [ ./assets ];
            };
        in
        {
          packages.site = built;

          # A static site cannot surface a dead link at runtime, so the build
          # gate is where it fails: every root-relative href must name a file in
          # the output, and must stay under the published subpath.
          checks = {
            site = built;
            links = lib.site.checkLinks { name = "hub"; basePath = config.basePath; } built;
            routes = pkgs.runCommand "hub-routes" { } ''
              test -f ${built}/index.html
              test -f ${built}/about/index.html
              test -f ${built}/assets/css/style.css
              grep -q '<title>${config.title}</title>' ${built}/index.html
              grep -q '<h1>About</h1>' ${built}/about/index.html
              grep -q 'href="/hub/about/"' ${built}/index.html
              grep -q 'href="/hub/assets/css/style.css"' ${built}/index.html
              # content/_index.md is a partial for the home page, not a route.
              test ! -e ${built}/_index/index.html
              touch $out
            '';
          };

          # `nix run .` serves the artifact Pages serves, under the same
          # subpath: the output's links are absolute (/hub/...), so serving it
          # at / would 404 every one of them.
          apps.default = {
            type = "app";
            program = "${pkgs.writeShellScript "hub-preview" ''
              set -eu
              root=$(mktemp -d)
              trap 'rm -rf "$root"' EXIT INT TERM
              ln -s ${built} "$root${config.basePath}"
              ${pkgs.python3}/bin/python3 -m http.server --bind 127.0.0.1 "''${PORT:-8000}" --directory "$root" &
              wait $!
            ''}";
            meta.description = "Serve the built site under ${config.basePath} on 127.0.0.1 (PORT overrides 8000)";
          };

          devShells.default = pkgs.mkShell {
            packages = [ pkgs.jq pkgs.python3 pkgs.nixpkgs-fmt ];
          };
        };
    in
    {
      packages = builtins.listToAttrs (map (s: {
        name = s;
        value = (forSystem s).packages;
      }) systems);
      devShells = builtins.listToAttrs (map (s: {
        name = s;
        value = (forSystem s).devShells;
      }) systems);
      apps = builtins.listToAttrs (map (s: {
        name = s;
        value = (forSystem s).apps;
      }) systems);
      checks = builtins.listToAttrs (map (s: {
        name = s;
        value = (forSystem s).checks;
      }) systems);
    };
}
