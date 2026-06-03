{
  description = "Java 25 gradle 9 development environment";

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
            gradle_9-unwrapped
          ];

          JAVA_HOME = "${pkgs.openjdk25.home}";

          shellHook = ''
            echo "Java 25 + gradle development environment"
          '';
        };
      }
    );
}
