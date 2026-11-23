# TimeTrack — handoff / resume notes

_Last saved: 2026-11-23. Git repo is initialized, committed, and pushed to
`git@github.com:SafriXV/tt.git` (`main`). GitHub Pages is enabled with
`build_type=workflow`; a Pages deploy workflow is present at
`.github/workflows/pages.yml` and was triggered by the last push._

## What exists now

- `src/Main.hs`, `src/TimeTrack/{Model,Store,View}.hs` — the whole app in
  Haskell. One codebase, CPP-selected backend:
  - native: `-DNATIVE` (cabal flag `-fnative`), Lynx elements + `native`
  - web: normal `miso` + `startApp`
- `timetrack.cabal`, `cabal.project`, `flake.nix`, `flake.lock` — Nix builds:
  - `nix build .#bundle --accept-flake-config -L` → `result/main.lynx.bundle`
  - `nix build .#web --accept-flake-config -L` → static site in `result/`
- `styles.css`, `web/index.html` — shared styling + browser loader page.
- `android/` — minimal Lynx host app, Java storage module
  (`NativeLocalStorageModule`), signing config and local keystore in
  `keystore/timetrack.jks` (password `timetrack`).
- `scripts/build-apk.sh` — one-shot bundle + `gradle assembleRelease` + copy
  to `dist/timetrack.apk`.
- `.github/workflows/pages.yml` — builds `.#web` with Nix and deploys to Pages.

## Where I got stuck / what is NOT verified

1. **The Haskell code has never been compiled.** An early `nix build .#bundle`
   was still downloading/building the GHCJS toolchain when it was interrupted;
   later attempts failed only because files were untracked by Git (now fixed).
   Expect compile errors, especially around:
   - `Miso.Native.X.Element.input_` / `P.textProp "placeholder"` imports
   - `View` type arity / `Attribute` exports
   - `Miso.JSON.decode` use in `Model.hs` (`Boot`)
   - JS FFI return types (`MisoString` from `foreign import javascript`)
2. **`web` site derivation in `flake.nix` is a best guess.** It assumes
   `${webApp}/bin/timetrack.jsexe/all.js`; verify against a real build.
   **Known immediate bug:** `flake.nix:38` uses
   `lib.relativeTo ./. path != "cabal.project"` inside `cleanSourceWith`, but
   `lib.relativeTo` does not exist in the pinned nixpkgs — this is what makes
   the Pages workflow fail at evaluation time. Fix: drop the `cleanSourceWith`
   filter and pass `./.` to `callCabal2nix`; the existing
   `postPatch = "rm -f cabal.project\n"` already handles the project file.
3. **Android Java module is unverified.** `NativeLocalStorageModule` uses the
   researched Lynx API (`LynxModule`, `@LynxMethod`, `Callback`,
   `LynxEnv.inst().registerModule`), but has not been compiled/loaded on a
   device.
4. **No APK has been built yet.** Research verified Gradle 8.14.4 + JDK 17 +
   AGP 8.5.2 + SDK 34 works on this Mac (scratch build produced a 22 MB APK),
   with Lynx artifacts from Maven Central. Our own app still needs the bundle
   embedded and `assembleRelease` run.
5. The Pages workflow may currently be failing because of (1)/(2). Re-run it
   after the web build succeeds locally.

## Exact research results (already verified, don't re-research)

### Miso native API (pinned commit `56c9b2c…`)

```haskell
main = native (nativeEvents <> nativeXEvents) (static (mountStatic app))
-- mountStatic from Miso.Native (NOT mountStatic_)
-- component :: model -> (action -> Effect ctx props model action)
--           -> (model -> View ctx props model action) -> Component ...
-- i.e. view takes ONE argument, model
-- IE.onInput :: (InputEvent -> action) -> Attribute model action
-- InputEvent { inputValue :: MisoString, ... }
-- X.input_ :: [Attribute model action] -> View context props model action
-- className from Miso.Html.Property; single token per node in native CSS
```

`MountConstraints` under `NATIVE` requires ToJSON/FromJSON for model, props and
action (we derive these). `Miso.Native.Module.callNativeModule*` is BTS-only.

### Persistence

Java side (implemented in `android/.../NativeLocalStorageModule.java`) exposes:

```ts
NativeLocalStorageModule.setStorageItem(key, value)
NativeLocalStorageModule.getStorageItem(key, callback) // callback.invoke(value)
```

Haskell side in `Store.hs` uses `callNativeModule`/`callNativeModuleWith`.
Web build uses `Miso.Storage.getLocalStorage/setLocalStorage`.

### Build constraints

- `mkLynxBundle { name, jsDrv, exeName, styles, assets? }`, reads
  `${jsDrv}/bin/${exeName}.jsexe/all.js`, output `main.lynx.bundle`.
- Native package set: `miso.lib.${system}.ghcNative`;
  `callCabal2nixWithOptions ... "-fnative" { miso = ghcNative.miso-native; }`.
- Web: `pkgs.pkgsCross.ghcjs.haskell.packages.ghc9141` with the miso overlay.
- Use `--accept-flake-config` to enable `haskell-miso-cachix` (cachix CLI is not
  installed; local nix.conf has no cachix substituter).
- Android: JDK **17** (local Java 26 is too new for Gradle 8), Gradle 8.7+,
  AGP 8.5.2, compileSdk 34, build-tools 34.0.0; set `ANDROID_HOME`,
  `ANDROID_SDK_ROOT`, `JAVA_HOME` and
  `GRADLE_OPTS=-Dorg.gradle.project.android.aapt2FromMavenOverride=.../aapt2`.
  Pure `nix build` of the APK is not realistic (Maven network access).

## Resume checklist

```bash
cd /Users/safri/Projects/tt
# 0. First remove the broken lib.relativeTo filter in flake.nix:36-39 and
#    callCabal2nix "timetrack" ./.  (see note above) — otherwise every
#    nix build / Pages workflow fails at evaluation time.
nix build .#bundle --accept-flake-config -L     # fix Haskell compile errors
nix build .#web --accept-flake-config -L        # fix web site path if needed
./scripts/build-apk.sh                          # produces dist/timetrack.apk
git add -A && git commit -m "..." && git push
# re-run the Pages workflow after web build is green:
gh workflow run pages.yml
```

Hosted URL (once workflow succeeds): https://safrixv.github.io/tt/
