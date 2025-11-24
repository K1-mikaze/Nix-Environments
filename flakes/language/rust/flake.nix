{
  description = ''
  === Rust Development Environment
  - Don't forget to stage you git after initialize a cargo project or the flake will stop working
  - Remember to change the Nix-chanel to your prefered one **https://nixos.wiki/wiki/Nix_channels**
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; # Change this channel if you want
  };

  outputs = {self,nixpkgs}: let 
  pkgs = nixpkgs.legacyPackages."x86_64-linux";
  system = "x86_64-linux";
  in {
    devShells.${system}.default = pkgs.mkShell
    {
      buildInputs = with pkgs; [
      cargo
      rustc
      rustfmt
      clippy
      rust-analyzer
      glib
      ];
      
      nativeBuildInputs = with pkgs; [ pkg-config ];
      env.RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
    };
  };
}
