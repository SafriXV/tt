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
        ghcNativeBase = miso.lib.${system}.ghcNative;

        # Keep local build artifacts and logs out of the derivation sources.
        src = lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            let name = builtins.baseNameOf path;
                ignoredDirs = [ ".git" ".build" "dist" "result" "build" ".gradle" ];
            in ! (type == "directory" &&
                  (builtins.elem name ignoredDirs || lib.hasPrefix "result-" name))
               && ! lib.hasSuffix ".log" (builtins.toString path);
        };

        # Browser (GitHub Pages) build of the same Haskell sources. The miso
        # overlay supplies the GHCJS 9.14.1 package set.
        webPkgsBase = (import miso.inputs.nixpkgs {
          inherit system;
          overlays = [ miso.overlays.default ];
        }).pkgsCross.ghcjs.haskell.packages.ghc9141;

        # Apple's ranlib pads wasm objects with '\n'; GHC 9.14's archive reader
        # passes that padding to wasm-ld, which fails with "section too large".
        # Patch the *plain* cross GHC: miso's ghcNative overlay adds jsbi.patch
        # on top of whatever GHC we pass in, so patching its already-overridden
        # ghc would apply jsbi.patch twice and break the build.
        patchedGhc = webPkgsBase.ghc.overrideAttrs (old: {
          patches = (old.patches or []) ++ [ ./patches/ghc-9.12-js-ar-darwin-ranlib-padding.patch ];
        });

        ghcNative = ghcNativeBase.override { ghc = patchedGhc; };

        # The web backend uses GHCJS, which does not read GHC's JS-backend
        # archives; it needs no Darwin patch (and CI runs on Linux).
        webPkgs = webPkgsBase;

        # The checked-in cabal.project pins miso as a git
        # source-repository-package, which conflicts with the package set the
        # miso overlay supplies. Remove it from both derivation sources.
        withoutProjectFile = drv: drv.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + "rm -f cabal.project\n";
        });

        webApp = withoutProjectFile (webPkgs.callCabal2nix "timetrack" (src) {
          miso = webPkgs.miso;
        });

        web = pkgs.runCommand "timetrack-web" { } ''
          mkdir -p "$out"
          cp ${./web/index.html} "$out/index.html"
          cp ${./styles.css} "$out/styles.css"
          cp ${webApp}/bin/timetrack.jsexe/all.js "$out/all.js"
        '';

        # Haskell executable, built with GHC's JavaScript backend against
        # miso's native (LynxJS dual-thread) backend.
        app = withoutProjectFile (ghcNative.callCabal2nixWithOptions "timetrack" (src) "-fnative" {
          miso = ghcNative.miso-native;
        });

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
