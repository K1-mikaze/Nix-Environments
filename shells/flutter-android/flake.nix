{
  description = "Flutter + Android SDK build environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    android-emulator = {
      url = "path:../android-emulator";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      android-nixpkgs,
      android-emulator,
    }:
    let
      pkgsx86 = import nixpkgs {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };
      androidEnvx86 = android-nixpkgs.sdk.x86_64-linux (
        sdkPkgs: with sdkPkgs; [
          cmdline-tools-latest
          build-tools-36-0-0
          platform-tools
          platforms-android-36
          ndk-27-0-12077973
        ]
      );

      flutterAppx86 =
        let
          patchedFlutterx86 = pkgsx86.flutter.overrideAttrs (oldAttrs: {
            patchPhase = ''
              runHook prePatch
              substituteInPlace $FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterTask.kt \
                --replace 'val cmakeExecutable = project.file(cmakePath).absolutePath' 'val cmakeExecutable = "cmake"' \
                --replace 'val ninjaExecutable = project.file(ninjaPath).absolutePath' 'val ninjaExecutable = "ninja"'
              find $FLUTTER_ROOT -name "*.gradle" -o -name "*.gradle.kts" | xargs -I {} \
                sed -i 's|cmake/[^/]*/bin/cmake|cmake|g' {} 2>/dev/null || true
              find $FLUTTER_ROOT/packages/flutter_tools -name "*.dart" | xargs -I {} \
                sed -i 's|/cmake/[^/]*/bin/cmake|cmake|g' {} 2>/dev/null || true
              runHook postPatch
            '';
          });
        in
        pkgsx86.writeShellScriptBin "flutter" ''
          #!/usr/bin/env bash
          set -e

          export ANDROID_SDK_ROOT="${androidEnvx86}/share/android-sdk"
          export ANDROID_HOME="$ANDROID_SDK_ROOT"
          export JAVA_HOME="${pkgsx86.jdk17}"
          export PATH="${pkgsx86.cmake}/bin:${pkgsx86.ninja}/bin:${patchedFlutterx86}/bin:$PATH"

          if [ -d "$PWD/.android/sdk" ]; then
            export ANDROID_HOME="$PWD/.android/sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
          fi

          exec "${patchedFlutterx86}/bin/flutter" "$@"
        '';
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        androidEnv = android-nixpkgs.sdk.${system} (
          sdkPkgs: with sdkPkgs; [
            cmdline-tools-latest
            build-tools-36-0-0
            platform-tools
            platforms-android-36
            ndk-27-0-12077973
          ]
        );

        patchedFlutter = pkgs.flutter.overrideAttrs (oldAttrs: {
          patchPhase = ''
            runHook prePatch

            substituteInPlace $FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterTask.kt \
              --replace 'val cmakeExecutable = project.file(cmakePath).absolutePath' 'val cmakeExecutable = "cmake"' \
              --replace 'val ninjaExecutable = project.file(ninjaPath).absolutePath' 'val ninjaExecutable = "ninja"'

            find $FLUTTER_ROOT -name "*.gradle" -o -name "*.gradle.kts" | xargs -I {} \
              sed -i 's|cmake/[^/]*/bin/cmake|cmake|g' {} 2>/dev/null || true

            find $FLUTTER_ROOT/packages/flutter_tools -name "*.dart" | xargs -I {} \
              sed -i 's|/cmake/[^/]*/bin/cmake|cmake|g' {} 2>/dev/null || true

            runHook postPatch
          '';
        });

      in
      {
        devShells.default =
          (pkgs.buildFHSEnv {
            name = "FHS flutter-android-dev-env";
            targetPkgs =
              pkgs: with pkgs; [
                bashInteractive
                git
                which
                cmake
                ninja
                python3
                jdk17
                nix-ld
                gradle
                patchedFlutter
                androidEnv
                patchelf
                glibc
                zlib
                ncurses5
                stdenv.cc.cc.lib
              ];

            multiPkgs =
              pkgs: with pkgs; [
                zlib
                ncurses5
                mesa
              ];

            profile = ''
              echo "FHS shell is active. Setting up Flutter+Android environment..."
              export PATH="$FHS_LIB/usr/bin:$PATH"
              export NIX_LD_LIBRARY_PATH="${
                pkgs.lib.makeLibraryPath [
                  pkgs.glibc
                  pkgs.zlib
                  pkgs.ncurses5
                  pkgs.stdenv.cc.cc.lib
                ]
              }"
              export LD_LIBRARY_PATH="$NIX_LD_LIBRARY_PATH:$LD_LIBRARY_PATH"

              if [ -f "$PWD/.flutter_env_ready" ] && [ -d "$PWD/.android/sdk" ]; then
                export ANDROID_HOME="$PWD/.android/sdk"
                export ANDROID_SDK_ROOT="$ANDROID_HOME"
                export JAVA_HOME="${pkgs.jdk17}"
                export PATH="${pkgs.cmake}/bin:${pkgs.ninja}/bin:$PATH"
                export LD_LIBRARY_PATH="$FHS_LIB/usr/lib:$LD_LIBRARY_PATH"

                echo "✅ Flutter environment ready!"
                echo "👉 To launch the emulator: nix run .#emulator"
                echo "👉 To build: flutter build apk --release"
              else
                echo "Performing first-time SDK setup..."

                echo "Stopping any existing ADB server..."
                "${androidEnv}/share/android-sdk/platform-tools/adb" kill-server &> /dev/null || true

                mkdir -p "$PWD/.android/sdk"
                export ANDROID_HOME="$PWD/.android/sdk"
                export ANDROID_SDK_ROOT="$ANDROID_HOME"
                export JAVA_HOME="${pkgs.jdk17}"

                echo "🔧 Using Java:"
                "$JAVA_HOME/bin/java" -version

                mkdir -p "$ANDROID_HOME/licenses" "$ANDROID_HOME/avd" "$ANDROID_HOME/bin"

                cp -LR ${androidEnv}/share/android-sdk/* "$ANDROID_HOME/" || true

                for bin in adb avdmanager sdkmanager; do
                  cp -LR ${androidEnv}/bin/$bin "$ANDROID_HOME/bin/" || true
                done
                rm -rf "$ANDROID_HOME/cmake"

                mkdir -p "$ANDROID_HOME/cmake/3.22.1/bin"

                ln -sf "$(which cmake)" "$ANDROID_HOME/cmake/3.22.1/bin/cmake"
                ln -sf "$(which ninja)" "$ANDROID_HOME/cmake/3.22.1/bin/ninja"

                chmod -R u+w "$ANDROID_HOME"

                find "$ANDROID_HOME/bin" "$ANDROID_HOME/platform-tools" \
                     "$ANDROID_HOME/cmdline-tools/latest/bin" \
                     "$ANDROID_HOME/build-tools" "$ANDROID_HOME/platforms" \
                     "$ANDROID_HOME/ndk" -type f -exec chmod +x {} \; 2>/dev/null || true

                for license in android-sdk-license android-sdk-preview-license googletv-license; do
                  touch "$ANDROID_HOME/licenses/$license"
                done
                yes | flutter doctor --android-licenses || true

                flutter config --android-sdk "$ANDROID_HOME"

                export PATH="${pkgs.cmake}/bin:${pkgs.ninja}/bin:$PATH"

                echo "🔧 Using CMake: $(which cmake) ($(cmake --version | head -1))"
                echo "🔧 Using Ninja: $(which ninja) ($(ninja --version))"

                flutter doctor --quiet
                echo "✅ Flutter + Android SDK ready."

                touch "$PWD/.flutter_env_ready"

                echo "👉 To create a project: flutter create my_app"
                echo "👉 To launch the emulator: nix run .#emulator"
                echo "👉 To build: flutter build apk --release"
              fi
            '';
            runScript = "bash";
          }).env;
      }
    )
    // {
      apps.x86_64-linux.emulator = {
        type = "app";
        program = "${android-emulator.packages.x86_64-linux.run-emulator}/bin/run-emulator";
      };
    };
}
