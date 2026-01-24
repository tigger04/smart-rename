{
  description = "AI-powered file renaming tool that generates intelligent, descriptive filenames";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        smart-rename = pkgs.callPackage ./default.nix {};
      in
      {
        packages = {
          default = smart-rename;
          smart-rename = smart-rename;
        };

        apps = {
          default = {
            type = "app";
            program = "${smart-rename}/bin/smart-rename";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            curl
            jq
            yq-go
            fd
            poppler_utils
            ollama
            # Development tools
            nixpkgs-fmt
          ];

          shellHook = ''
            echo "Smart-rename development environment"
            echo "Run 'make test' to run tests"
            echo "Run './smart-rename --version' to test the script"
          '';
        };
      }
    );
}