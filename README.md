# Nix Environments

This repository focuses on making developer environment setup with Nix easier and more accessible.

## Requirements

- The Nix package manager with the experimental features `flakes` and `nix-command` enabled.

Install Nix at <https://nixos.org/download/>, then enable flakes:

```nix
experimental-features = nix-command flakes
```

Add the line above to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`.

## What is `nix develop`?

`nix develop` creates isolated, reproducible development environments with pinned dependency versions. Every shell in this repo uses Nix Flakes — locked in `flake.lock` — so everyone gets the exact same environment, every time.

Think of it as a "version-controlled, reproducible toolbox" that you open when working on a project and close when you're done, leaving your system clean.

Key advantages over traditional `nix-shell`:

- **Reproducible** — `flake.lock` pins exact versions for every dependency
- **Discoverable** — `nix flake show` lists all available shells
- **Composable** — environments can reference and depend on each other
- **CI/CD parity** — same environment in development and builds
- **Clean** — no global package pollution

# Available Shells

## Usage

```bash
nix develop .#<name>     # enter a dev shell
nix run .#emulator        # launch Android emulator
nix flake show            # list all available shells
nix develop github:sergioia-dev/nix-environments?dir=shells/<name>   # remote access
```

## Containerization

### Podman — `nix develop .#podman`
**Path:** `shells/podman`

A shell with Docker/Podman and Docker Compose available. Use it to run containers without installing Docker globally. All standard `docker` and `podman` commands work inside.

## Databases

### PostgreSQL — `nix develop .#postgredb`
**Path:** `shells/postgredb`

Automatically starts a PostgreSQL instance on the first available port (5432–5442). Creates a `.pgdata` directory for the database files. Auto-shuts down when you exit the shell. Connect with:
```bash
psql -p $(cat .pgdata/.pgport)
```

### MariaDB — `nix develop .#mariadb`
**Path:** `shells/mariadb`

Starts a MariaDB/MySQL instance. Creates a data directory and auto-shuts down on exit. Run `mysql -u root` to connect.

## Programming Languages

### Rust — `nix develop .#rust-minimal`
**Path:** `shells/rust-minimal`

Minimal Rust toolchain: `cargo`, `rustc`, `rustfmt`, `clippy`, `rust-analyzer`, plus `openssl`, `zlib`, and `pkg-config` for common crate builds. No extra tooling — start with `cargo init`.

### Flutter Android — `nix develop .#flutter-android`
**Path:** `shells/flutter-android`

Full Flutter + Android SDK environment. On first run, copies the SDK to `.android/sdk`, accepts licenses, and configures Flutter. Does not create or modify project files — run `flutter create my_app` yourself. Launch the emulator with `nix run .#emulator`.

### Java 25 + Maven — `nix develop .#java25-maven`
**Path:** `shells/java25-maven`

JDK 25 with Maven. `JAVA_HOME` is set automatically. Build with `mvn clean install`.

### Java 25 + Gradle — `nix develop .#java25-gradle`
**Path:** `shells/java25-gradle`

JDK 25 with Gradle 9. `JAVA_HOME` is set automatically. Build with `gradle build`.

## Utilities

### Android Emulator — `nix develop .#android-emulator`
**Path:** `shells/android-emulator`

Launches the Android emulator with hardware acceleration. Auto-kills the emulator process when the shell exits. Requires a valid AVD — create one with:
```bash
avdmanager create avd -n my_avd -k "system-images;android-36;google_apis;x86_64"
```
