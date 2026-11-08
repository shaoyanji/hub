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
        in
        {
          packages.site =
            lib.site.buildSite {
              name = "hub";
              basePath = config.basePath;
              pages = [
                (import ./site/pages/home.nix pageArgs)
                (import ./site/pages/about.nix pageArgs)
              ];
              assets = [ ./assets ];
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
    };
}
