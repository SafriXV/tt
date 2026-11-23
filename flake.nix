{
  description = "TimeTrack — frictionless offline time tracking, written in Haskell with miso native (LynxJS)";

  nixConfig = {
    extra-substituters = [ "https://haskell-miso-cachix.cachix.org" ];
    extra-trusted-public-keys = [
      "haskell-miso-cachix.cachix.org-1:m8hN1cvFMJtYib4tj+06xkKt5ABMSGfe8W7s40x1kQ0="
    ];
  };

  inputs.miso.url = "github:dmjio/miso";

  outputs = inputs:
    let
      miso = inputs.miso;
    in
    miso.inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (miso.inputs.nixpkgs) lib;
        pkgs = import miso.inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };
        ghcNative = miso.lib.${system}.ghcNative;

        # Browser (GitHub Pages) build of the same Haskell sources. The miso
        # overlay supplies the GHCJS 9.14.1 package set.
        webPkgs = (import miso.inputs.nixpkgs {
          inherit system;
          overlays = [ miso.overlays.default ];
        }).pkgsCross.ghcjs.haskell.packages.ghc9141;

        withoutProjectFile = lib.cleanSourceWith {
          src = ./.;
          filter = path: _type: lib.relativeTo ./. path != "cabal.project";
        };

        webApp = (webPkgs.callCabal2nix "timetrack" withoutProjectFile {
          miso = webPkgs.miso;
        }).overrideAttrs (old: {
          postPatch = (old.postPatch or "") + "rm -f cabal.project\n";
        });

        web = pkgs.runCommand "timetrack-web" { } ''
          mkdir -p "$out"
          cp ${./web/index.html} "$out/index.html"
          cp ${./styles.css} "$out/styles.css"
          cp ${webApp}/bin/timetrack.jsexe/all.js "$out/all.js"
        '';

        # Haskell executable, built with GHC's JavaScript backend against
        # miso's native (LynxJS dual-thread) backend.
        app = ghcNative.callCabal2nixWithOptions "timetrack" (lib.cleanSource ./.) "-fnative" {
          miso = ghcNative.miso-native;
        };

        # The Lynx bundle consumed by the Android host app.
        bundle = miso.lib.${system}.mkLynxBundle {
          name = "timetrack-bundle";
          jsDrv = app;
          exeName = "timetrack";
          styles = ./styles.css;
        };

        # Android SDK / JDK / Gradle, all fetched by Nix. Gradle still
        # resolves Lynx artifacts from Maven when assembling the APK.
        androidComposition = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "34" ];
          buildToolsVersions = [ "34.0.0" ];
          abiVersions = if pkgs.stdenv.hostPlatform.isAarch64
                        then [ "arm64-v8a" ]
                        else [ "x86_64" ];
          includeNDK = false;
        };
      in
      {
        packages = {
          default = bundle;
          inherit bundle app web;
        };

        devShells = {
          default = miso.devShells.${system}.default;
          native = miso.devShells.${system}.native;
          android = pkgs.mkShell {
            packages = [
              androidComposition.androidsdk
              pkgs.jdk17
              pkgs.gradle
            ];
            ANDROID_HOME = "${androidComposition.androidsdk}/libexec/android-sdk";
            ANDROID_SDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk";
            GRADLE_OPTS =
              "-Dorg.gradle.project.android.aapt2FromMavenOverride=" +
              "${androidComposition.androidsdk}/libexec/android-sdk/build-tools/34.0.0/aapt2";
          };
        };
      });
}
