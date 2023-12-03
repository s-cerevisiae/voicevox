{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, ... }:
    let system = "x86_64-linux";
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        node = pkgs.nodejs_18;
        electron = pkgs.electron_27;
    in {
      packages.${system}.default = pkgs.buildNpmPackage {
        pname = "voicevox";
        version = "999.999.999";
        src = ./.;

        nativeBuildInputs = [
          node
          pkgs.jq
          pkgs.makeWrapper
        ];

        env = {
          ELECTRON_OVERRIDE_DIST_PATH = "${electron}/libexec/electron";
          ELECTRON_SKIP_BINARY_DOWNLOAD = 1;

          VITE_DEFAULT_ENGINE_INFOS= ''[
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

        preBuild = ''
          if [[ $(jq --raw-output '.devDependencies.electron' < package.json | grep -E --only-matching '^[0-9]+') != ${lib.escapeShellArg (lib.versions.major electron.version)} ]]; then
            echo 'ERROR: electron version mismatch'
            exit 1
          fi
        '';

        buildPhase = ''
          runHook preBuild

          npx cross-env VITE_TARGET=electron vite build

          ln -s ${pkgs._7zz}/bin/7zz build/vendored/7z/7zzs

          npx electron-builder --dir \
            --config electron-builder.config.js \
            -c.electronDist=${electron}/libexec/electron \
            -c.electronVersion=${electron.version}

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          mkdir $out

          pushd dist_electron/linux-unpacked
          mkdir -p $out/opt/voicevox
          cp -r locales resources{,.pak} $out/opt/voicevox
          popd

          makeWrapper '${electron}/bin/electron' "$out/bin/voicevox" \
            --add-flags $out/opt/voicevox/resources/app.asar \
            --set-default ELECTRON_IS_DEV 0 \
            --inherit-argv0

          runHook postInstall
        '';
      };
    };
}
