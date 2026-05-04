{
  description = "Podman container tools development shell, in this shell you can run docker/podman containers with podman/docker and podman/docker compose";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # To use this shell on NixOS your user needs to be configured as such:
          # users.extraUsers.adisbladis = {
          #   subUidRanges = [{ startUid = 100000; count = 65536; }];
          #   subGidRanges = [{ startGid = 100000; count = 65536; }];
          # };

          podmanSetupScript =
            let
              registriesConf = pkgs.writeText "registries.conf" ''
                [registries.search]
                registries = ['docker.io']
                [registries.block]
                registries = []
              '';
            in
            pkgs.writeScript "podman-setup" ''
              #!${pkgs.runtimeShell}
              # Dont overwrite customised configuration
              if ! test -f ~/.config/containers/policy.json; then
                install -Dm555 ${pkgs.skopeo.src}/default-policy.json ~/.config/containers/policy.json
              fi
              if ! test -f ~/.config/containers/registries.conf; then
                install -Dm555 ${registriesConf} ~/.config/containers/registries.conf
              fi
            '';

          dockerCompat = pkgs.runCommand "docker-podman-compat" { } ''
            mkdir -p $out/bin
            ln -s ${pkgs.podman}/bin/podman $out/bin/docker
          '';
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              dockerCompat
              pkgs.podman-compose
              pkgs.podman
              pkgs.runc
              pkgs.conmon
              pkgs.skopeo
              pkgs.slirp4netns
              pkgs.fuse-overlayfs
            ];

            shellHook = ''
              # Install required configuration
              ${podmanSetupScript}
            '';
          };
        }
      );
    };
}
