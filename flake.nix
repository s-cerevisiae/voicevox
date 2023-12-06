rec {
  description = "無料で使える中品質なテキスト読み上げソフトウェア。エディターのみ。";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    lib = pkgs.lib;
    node = pkgs.nodejs_18;
    electron = pkgs.electron_27;
    _7z = pkgs._7zz;
  in rec {
    devShells.${system}.default = pkgs.mkShellNoCC {
      packages = [ node.pkgs.typescript-language-server ];
      inputsFrom = [ packages.${system}.default ];
    };
    packages.${system}.default = pkgs.buildNpmPackage {
      pname = "voicevox";
      version = "999.999.999";
      src = ./.;

      nativeBuildInputs = [
        node
        pkgs.jq
        pkgs.makeWrapper
        pkgs.copyDesktopItems
      ];

      buildInputs = [ _7z ];

      env = {
        ELECTRON_SKIP_BINARY_DOWNLOAD = 1;

        VITE_DEFAULT_ENGINE_INFOS = ''[
          {
              "uuid": "074fc39e-678b-4c13-8916-ffca8d505d1d",
              "name": "VOICEVOX Engine",
              "executionEnabled": false,
              "executionFilePath": "vv-engine/run.exe",
              "executionArgs": [],
              "host": "http://127.0.0.1:50021"
          }
        ]'';
      };

      npmDepsHash = "sha256-AWVqm8Z56f2eJe/4nR/HcV/PXcpTX/uR+N9igLJjZCI=";

      npmFlags = [ "--ignore-scripts" ];

      patches = [ ./patches/override_7z.patch ];

      preBuild = ''
        if [[ $(jq --raw-output '.devDependencies.electron' < package.json | grep -E --only-matching '^[0-9]+') != ${lib.escapeShellArg (lib.versions.major electron.version)} ]]; then
          echo 'ERROR: electron version mismatch'
          exit 1
        fi
      '';

      buildPhase = ''
        runHook preBuild

        export VITE_TARGET=electron
        export VITE_APP_BASE=$out/share/lib/voicevox

        npx vite build

        touch build/vendored/7z/7zzs

        npx electron-builder --dir \
          --config electron-builder.config.js \
          -c.electronDist=${electron}/libexec/electron \
          -c.electronVersion=${electron.version}

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        pushd dist_electron/linux-unpacked
        mkdir -p $out/share/lib/voicevox
        cp -r locales resources{,.pak} $out/share/lib/voicevox
        popd

        ln -s ${_7z}/bin/7zz $out/share/lib/voicevox/7zzs

        makeWrapper '${electron}/bin/electron' "$out/bin/voicevox" \
          --add-flags $out/share/lib/voicevox/resources/app.asar \
          --set-default ELECTRON_IS_DEV 0 \
          --inherit-argv0

        icondir=$out/share/icons/hicolor/256x256/apps
        mkdir -p $icondir
        cp dist/icon.png $icondir/voicevox.png

        runHook postInstall
      '';

      desktopItems = [
        (pkgs.makeDesktopItem {
          name = "voicevox";
          exec = "voicevox %U";
          icon = "voicevox";
          comment = description;
          desktopName = "VOICEVOX";
          categories = [ "AudioVideo" ];
        })
      ];
    };
  };
}
