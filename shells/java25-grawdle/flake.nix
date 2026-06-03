{
  description = "Java 25 maven development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            openjdk25
            maven
          ];

          JAVA_HOME = "${pkgs.openjdk25.home}";

          shellHook = ''
            echo "Java 25 development environment"
            fi
          '';
        };
      }
    );
}
