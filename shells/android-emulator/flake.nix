{
  description = "Android Emulator environment compatible with Flutter, React Native, and other dev tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      android-nixpkgs,
    }:
    let
      pkgsx86 = import nixpkgs {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };
      androidEnvx86 =
        android-nixpkgs.sdk.x86_64-linux (
          sdkPkgs: with sdkPkgs; [
            cmdline-tools-latest
            platform-tools
            emulator
            system-images-android-36-google-apis-playstore-x86-64
          ]
        )
        // {
          buildInputs =
            (androidEnvx86.buildInputs or [ ])
            ++ (with pkgsx86; [
              xcb-util-cursor
              libxcursor
              libx11
              libxcb
              qt6.qtbase
              qt6.qtsvg
            ]);
        };
      libPathx86 = pkgsx86.lib.makeLibraryPath (
        with pkgsx86;
        [
          glibc
          zlib
          ncurses5
          pkgsx86.stdenv.cc.cc.lib
          libsForQt5.qt5.qtbase
          libsForQt5.qt5.qtsvg
          libsForQt5.qt5.qtwayland
          qt6.qtbase
          qt6.qtsvg
          libx11
          libxext
          libxfixes
          libxi
          libxrandr
          libxrender
          libxcb
          libxcb-util
          libxcb-wm
          libxcb-image
          libxcb-keysyms
          libxcb-render-util
          libxkbcommon
          mesa
          libdrm
          vulkan-loader
          libglvnd
          linuxPackages.nvidia_x11
          fontconfig
          freetype
          dbus
          libpulseaudio
          pipewire
          udev
          libinput
          libevdev
          gtk3
          gdk-pixbuf
          cairo
          pango
          harfbuzz
          glib
          gsettings-desktop-schemas
          xcb-util-cursor
          libxcursor
        ]
      );
      emulatorAppx86 = pkgsx86.writeShellScriptBin "run-emulator" ''
        echo "Launching emulator ..."
        echo "🔐 Granting local X access with xhost for DISPLAY=$DISPLAY..."
        NIX_XHOST="${pkgsx86.xhost}/bin/xhost"

        if [ -x "$NIX_XHOST" ] && [ -n "$DISPLAY" ]; then
          "$NIX_XHOST" +local: > /dev/null
          if [ $? -eq 0 ]; then
            XHOST_CLEANUP=true
            echo "✅ X access granted successfully via Nix-xhost."
          else
            echo "❌ Nix-xhost command failed. Authorization may still be blocked."
            XHOST_CLEANUP=false
          fi
        else
          echo "⚠️ Warning: Nix-xhost binary not found at $NIX_XHOST or DISPLAY not set. Fix skipped."
          XHOST_CLEANUP=false
        fi

        export LD_LIBRARY_PATH="${libPathx86}:$LD_LIBRARY_PATH"

        if [ -n "$WAYLAND_DISPLAY" ]; then
          echo "🌿 Wayland detected: $WAYLAND_DISPLAY"
          USE_WAYLAND=true
          if [ -z "$DISPLAY" ]; then
            export DISPLAY=:0
          fi
          export QT_QPA_PLATFORM=xcb
        else
          echo "🖥️  X11 detected: ${"DISPLAY:-:0"}"
          USE_WAYLAND=false
          export QT_QPA_PLATFORM=xcb
        fi

        export QT_QPA_PLATFORM=xcb
        export QT_QPA_PLATFORM_PLUGIN_PATH="${pkgsx86.qt6.qtbase}/lib/qt-6/plugins"
        export QT_PLUGIN_PATH="${pkgsx86.qt6.qtbase}/lib/qt-6/plugins"
        export QML2_IMPORT_PATH="${pkgsx86.qt6.qtbase}/lib/qt-6/qml"
        export QTWEBENGINE_DISABLE_SANDBOX=1
        export QT_OPENGL=desktop
        export QT_QPA_PLATFORMTHEME=gtk3
        export QT_ACCESSIBILITY=1
        export QT_IM_MODULE=compose
        export XMODIFIERS=@im=none
        export GTK_IM_MODULE=gtk-im-context-simple
        export QT_LOGGING_RULES="qt.qpa.input=true;qt.qpa.input.events=true"
        export QT_QPA_GENERIC_PLUGINS=""
        export QT_QPA_ENABLE_TERMINAL_KEYBOARD=1
        export SDL_VIDEODRIVER=x11
        export XKB_DEFAULT_LAYOUT=us

        LD_PATH_BASE="${libPathx86}"

        if [ -d "/run/opengl-driver" ]; then
            echo "✅ NVIDIA/OpenGL driver detected"
            export LD_LIBRARY_PATH="/run/opengl-driver/lib:${libPathx86}:$LD_LIBRARY_PATH"
            export LIBGL_DRIVERS_PATH="/run/opengl-driver/lib/dri"
            export MESA_LOADER_DRIVER_OVERRIDE=""
        else
            echo "⚠️ NVIDIA driver not found, using Mesa fallback"
            export LD_LIBRARY_PATH="${pkgsx86.mesa}/lib:${pkgsx86.libdrm}/lib:${pkgsx86.vulkan-loader}/lib:${libPathx86}:$LD_LIBRARY_PATH"
            export LIBGL_DRIVERS_PATH="${pkgsx86.mesa}/lib/dri"
            export MESA_LOADER_DRIVER_OVERRIDE=i965
        fi

        if [ -d "/run/opengl-driver" ]; then
            echo "⚠️ Forcing Vulkan/Mesa device selection for NVIDIA"
            export MESA_VULKAN_DEVICE_SELECT="${pkgsx86.vulkan-loader}/etc/vulkan/icd.d/nvidia_icd.json"
        fi

        export QEMU_GL_ENABLE=1
        export QEMU_VULKAN_ENABLE=1
        export LD_PRELOAD="${pkgsx86.libglvnd}/lib/libGL.so.1"

        HOME_EMULATOR_CONFIG_DIR="$HOME/.android/avd/android_emulator.avd"
        if [ -d "$HOME_EMULATOR_CONFIG_DIR" ]; then
          echo "📝 Found AVD in home directory: $HOME_EMULATOR_CONFIG_DIR"
          if [ -f "$HOME_EMULATOR_CONFIG_DIR/config.ini" ]; then
            if grep -q "^hw\.keyboard\s*=" "$HOME_EMULATOR_CONFIG_DIR/config.ini"; then
              sed -i 's/^hw\.keyboard\s*=.*/hw.keyboard=yes/' "$HOME_EMULATOR_CONFIG_DIR/config.ini"
            else
              echo "hw.keyboard=yes" >> "$HOME_EMULATOR_CONFIG_DIR/config.ini"
            fi
            if grep -q "^hw\.mainKeys\s*=" "$HOME_EMULATOR_CONFIG_DIR/config.ini"; then
              sed -i 's/^hw\.mainKeys\s*=.*/hw.mainKeys=yes/' "$HOME_EMULATOR_CONFIG_DIR/config.ini"
            else
              echo "hw.mainKeys=yes" >> "$HOME_EMULATOR_CONFIG_DIR/config.ini"
            fi
            if grep -q "^hw\.dPad\s*=" "$HOME_EMULATOR_CONFIG_DIR/config.ini"; then
              sed -i 's/^hw\.dPad\s*=.*/hw.dPad=yes/' "$HOME_EMULATOR_CONFIG_DIR/config.ini"
            else
              echo "hw.dPad=yes" >> "$HOME_EMULATOR_CONFIG_DIR/config.ini"
            fi
            echo "✅ Updated home directory emulator configuration"
          fi
        fi

        if $XHOST_CLEANUP; then
          trap "xhost -local: > /dev/null; echo '✅ X access revoked.'" EXIT
        fi

        export ANDROID_SDK_ROOT="${androidEnvx86}/share/android-sdk"
        export ANDROID_HOME="$ANDROID_SDK_ROOT"
        export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

        exec emulator -avd android_emulator -gpu host -delay-adb -no-snapshot -no-snapshot-load -no-snapshot-save -port 5554 -grpc 8554 -qemu -enable-kvm
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

        androidEnv =
          android-nixpkgs.sdk.${system} (
            sdkPkgs: with sdkPkgs; [
              cmdline-tools-latest
              platform-tools
              emulator
              system-images-android-36-google-apis-playstore-x86-64
            ]
          )
          // {
            buildInputs =
              (androidEnv.buildInputs or [ ])
              ++ (with pkgs; [
                xcb-util-cursor
                libxcursor
                libx11
                libxcb
                qt6.qtbase
                qt6.qtsvg
              ]);
          };
      in
      {
        devShells.default =
          (pkgs.buildFHSEnv {
            name = "FHS-android-emulator-env";
            targetPkgs =
              pkgs: with pkgs; [
                bashInteractive
                git
                which
                jdk17
                androidEnv
                patchelf

                glibc
                zlib
                ncurses5
                stdenv.cc.cc.lib

                libsForQt5.qt5.qtbase
                libsForQt5.qt5.qtsvg
                libsForQt5.qt5.qtwayland
                qt6.qt5compat
                qt6.qtbase
                qt6.qtsvg
                qt6.qtwayland
                libx11
                libxext
                libxfixes
                libxi
                libxrandr
                libxrender
                libxcb
                libxcb-util
                libxcb-wm
                libxcb-image
                libxcb-keysyms
                libxcb-render-util
                libxkbcommon

                mesa
                libdrm
                vulkan-loader
                fontconfig
                freetype
                linuxPackages.nvidia_x11
                libglvnd

                dbus
                libevdev
                libpulseaudio
                pipewire
                udev
                libinput
                at-spi2-atk
                at-spi2-core

                gtk3
                gdk-pixbuf
                cairo
                pango
                harfbuzz
                glib
                gsettings-desktop-schemas

                xcb-util-cursor
                libxcursor
                setxkbmap
                xauth
                xhost
                xset
              ];

            multiPkgs =
              pkgs: with pkgs; [
                zlib
                ncurses5
                mesa
              ];

            profile = ''
              echo "FHS shell active. Setting up Android Emulator environment..."

              export JAVA_HOME="${pkgs.jdk17}"

              if [ -d "$PWD/.android/sdk/system-images" ]; then
                echo "✅ Android SDK already set up at $PWD/.android/sdk"
                export ANDROID_HOME="$PWD/.android/sdk"
                export ANDROID_SDK_ROOT="$ANDROID_HOME"
                export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
              else
                echo "Performing initial Android SDK setup..."

                mkdir -p "$PWD/.android/sdk"
                export ANDROID_HOME="$PWD/.android/sdk"
                export ANDROID_SDK_ROOT="$ANDROID_HOME"
                export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

                echo "Copying Android SDK to writable location..."
                cp -LR ${androidEnv}/share/android-sdk/* "$ANDROID_HOME/" || true
                chmod -R u+w "$ANDROID_HOME"
                find "$ANDROID_HOME" -type f -exec chmod +x {} \; 2>/dev/null || true

                for license in android-sdk-license android-sdk-preview-license googletv-license; do
                  touch "$ANDROID_HOME/licenses/$license"
                done

                if ! avdmanager list avd | grep -q 'android_emulator'; then
                  echo "Creating default AVD: android_emulator"
                  yes | avdmanager create avd \
                    --name "android_emulator" \
                    --package "system-images;android-36;google_apis_playstore;x86_64" \
                    --device "pixel" \
                    --abi "x86_64" \
                    --tag "google_apis_playstore" \
                    --force
                fi

                HOME_AVD_CONFIG="$HOME/.android/avd/android_emulator.avd/config.ini"
                if [ -f "$HOME_AVD_CONFIG" ]; then
                  echo "Configuring AVD hardware settings..."
                  for setting in "hw.keyboard=yes" "hw.mainKeys=yes" "hw.dPad=yes"; do
                    key="''${setting%%=*}"
                    if grep -q "^$key\s*=" "$HOME_AVD_CONFIG"; then
                      sed -i "s/^$key\s*=.*/$setting/" "$HOME_AVD_CONFIG"
                    else
                      echo "$setting" >> "$HOME_AVD_CONFIG"
                    fi
                  done
                  echo "✅ AVD configured for full emulator functionality"
                fi

                echo "✅ Android Emulator environment ready!"
              fi

            '';
            runScript = "${pkgs.writeShellScript "fhs-entry" ''
              "${emulatorAppx86}/bin/run-emulator" &
              EMULATOR_PID=$!

              RCFILE=/tmp/.fhs-bashrc-$$
              cat > $RCFILE << EOF
source ~/.bashrc 2>/dev/null || true
cleanup() {
  echo "Stopping emulator..."
  adb emu kill 2>/dev/null
  kill $EMULATOR_PID 2>/dev/null
  pkill -f "qemu-system.*android_emulator" 2>/dev/null || true
  kill -9 $EMULATOR_PID 2>/dev/null
  echo "Emulator stopped."
}
trap cleanup EXIT INT TERM
EOF

              echo ""
              echo "✅ Emulator starting (PID: $EMULATOR_PID)"
              echo "   Connect via ADB at localhost:5554"

              exec bash --rcfile $RCFILE
            ''}";
          }).env;
      }
    )
    // {
      packages.x86_64-linux.run-emulator = emulatorAppx86;
    };
}
