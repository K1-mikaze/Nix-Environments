# Nix Environments

This repository focuses on making developer environment setup with Nix easier and more accessible.
## Nix Shells

### Requirements 

- The Nix package manager.

How to install it in any Unix system in  <https://nixos.org/download/> 

### What are Nix Shells?

A nix-shell is a temporary, isolated development environment created by the Nix package manager. It provides access to specific tools, libraries, and dependencies without installing them permanently on your system.

Think of it like a "project-specific toolbox" that you can open when working on a project and close when you're done, leaving your main system clean and unchanged.

### How Nix Shells Work

Nix Shells use a shell.nix file that defines the environment:

```nix
# shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    nodejs
    git
  ];
  
  shellHook = ''
    echo "Environment ready!"
  '';
}
```

Usage:

```bash
nix-shell
```

#### Problems Nix Shells Solve

- "It works on my machine!": You might have Node.js 18 globally, but your project needs Node.js 16

- Complex Dependencies: Projects needing specific, conflicting libraries or packages

- Onboarding New Developers: Eliminates long, error-prone setup instructions

- Clean System: No global package pollution

**Limitation:**  Uses whatever nixpkgs channel is currently active on your system.

## Nix Develop (Flakes)

### Requirements 

- The Nix package manager with the experimental feature `flakes` and `nix-command`  enable .

### What is Nix Develop?

nix develop is the modern, reproducible approach to development environments using Nix Flakes. It creates isolated environments with pinned, exact versions of all dependencies.

Think of it as a "version-controlled, reproducible toolbox" that guarantees everyone gets the exact same environment.

### How Nix Develop Works

Nix Develop uses a flake.nix file with locked versions:
```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; # Pinned version!
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: {
      devShells.default = let
        pkgs = nixpkgs.legacyPackages.${system};
      in pkgs.mkShell {
        packages = with pkgs; [
          python3
          nodejs_18  # Exact version
          postgresql_15
        ];
        
        shellHook = ''
          echo "🐚 Reproducible environment ready!"
        '';
      };
    });
}
```

Usage:

```bash
nix develop
```

### Key Advantages Over Nix Shells

- Reproducible: Locked dependencies in flake.lock ensure identical environments everywhere

- Discoverable: nix flake show reveals all available environments

- Composable: Easy to mix packages from different sources

- Modern: Part of the Nix Flakes ecosystem

### Problems Nix Develop Solves

- Version Drift: Everyone gets identical tool versions

- Broken Updates: Pinned dependencies prevent unexpected breakages

- Team Consistency: All developers use the same environment

- CI/CD Parity: Development environment matches production builds

# Current Available


## Flakes

### Databases
| Name | Path |
| -------------- | --------------- |
| PostgreSQL | [postgresql](./flakes/database/postgresql/flake.nix)|
| MySQL | [mariadb](./flakes/database/mysql/flake.nix)|

### Programming Languages

| Name | Path |
| -------------- | --------------- |
| Rust | [rust](./flakes/language/rust/flake.nix)|

## Nix Shell

any available at the moment
