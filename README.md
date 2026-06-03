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
nix develop .#<name>                                                         # enter a dev shell
nix run .#android-emulator                                                            # launch Android emulator
nix develop github:sergioia-dev/nix-environments#<name>                      # remote access (no clone)
```

| Category | Name | Path | Command | Description |
|---|---|---|---|---|
| **Containerization** | Podman | `shells/podman` | `nix develop github:sergioia-dev/nix-environments#podman` | Docker, Podman and Compose — run containers without global install |
| **Databases** | PostgreSQL | `shells/postgredb` | `nix develop github:sergioia-dev/nix-environments#postgredb` | Auto-starts on free port (5432–5442), auto-shutdown on exit — `psql -p $(cat .pgdata/.pgport)` |
| | MariaDB | `shells/mariadb` | `nix develop github:sergioia-dev/nix-environments#mariadb` | MySQL/MariaDB instance, auto-shutdown — `mysql -u root` |
| **Languages** | Rust | `shells/rust-minimal` | `nix develop github:sergioia-dev/nix-environments#rust-minimal` | cargo, rustc, rustfmt, clippy, rust-analyzer, openssl, zlib — `cargo init` to start |
| | Flutter Android | `shells/flutter-android` | `nix develop github:sergioia-dev/nix-environments#flutter-android` | Flutter + Android SDK — first-run copies SDK to `.android/sdk`, accepts licenses. No project file changes — `flutter create my_app` yourself |
| | Java 25 + Maven | `shells/java25-maven` | `nix develop github:sergioia-dev/nix-environments#java25-maven` | JDK 25, Maven, `JAVA_HOME` set — `mvn clean install` |
| | Java 25 + Gradle | `shells/java25-gradle` | `nix develop github:sergioia-dev/nix-environments#java25-gradle` | JDK 25, Gradle 9, `JAVA_HOME` set — `gradle build` |
| **Utilities** | Android Emulator | `shells/android-emulator` | `nix develop github:sergioia-dev/nix-environments#android-emulator` | Hardware-accelerated emulator, auto-kill on exit — create AVD: `avdmanager create avd -n my_avd -k "system-images;android-36;google_apis;x86_64"` |
