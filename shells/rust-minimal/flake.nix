{
  description = "Rust development environment";

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
            cargo
            rustc
            rustfmt
            clippy
            rust-analyzer
            openssl
            openssl.dev
            zlib
            zlib.dev
          ];

          nativeBuildInputs = with pkgs; [ pkg-config ];

          env.RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";

          shellHook = ''
            echo "🦀 Rust development environment"
            echo "   cargo build   — build project"
            echo "   cargo run     — run project"
            echo "   cargo test    — run tests"
            echo "   cargo fmt     — format code"
            echo "   cargo clippy  — lint code"
            if [ ! -f Cargo.toml ]; then
              echo ""
              echo "No Cargo project found. Create one with: cargo init"
            fi
          '';
        };
      }
    );
}
