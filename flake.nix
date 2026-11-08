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
          site =
            lib.site.buildSite {
              name = "hub";
              basePath = config.basePath;
              pages = [
                (import ./site/pages/home.nix pageArgs)
                (import ./site/pages/about.nix pageArgs)
              ];
              assets = [ ./assets ];
            };
        in
        {
          packages.site = site;

          # A static site cannot surface a dead link at runtime, so the build
          # gate is where it fails: every root-relative href must name a file in
          # the output, and must stay under the published subpath.
          checks = {
            site = site;
            links = lib.site.checkLinks { name = "hub"; basePath = config.basePath; } site;
            routes = pkgs.runCommand "hub-routes" { } ''
              test -f ${site}/index.html
              test -f ${site}/about/index.html
              test -f ${site}/assets/css/style.css
              grep -q '<title>${config.title}</title>' ${site}/index.html
              grep -q '<h1>About</h1>' ${site}/about/index.html
              grep -q 'href="/hub/about/"' ${site}/index.html
              grep -q 'href="/hub/assets/css/style.css"' ${site}/index.html
              touch $out
            '';
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
      checks = builtins.listToAttrs (map (s: {
        name = s;
        value = (forSystem s).checks;
      }) systems);
    };
}
