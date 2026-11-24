# TimeTrack — handoff / resume notes

_Last saved: 2026-11-24. Git repo is on `main`, pushed to
`git@github.com:SafriXV/tt.git` at commit `a984531` (plus a final `.gitignore`
tidy-up). Everything below is built, signed, deployed and verified._

## Goal

A dead-simple, fully offline time tracker: one Haskell/Miso codebase, a native
Android APK, and a web build on GitHub Pages. Tapping one of 16 emoji tiles logs
the activity with the current time; notes can be added/edited/deleted; the day's
logs are viewable. Android uses Lynx + a Java `SharedPreferences` bridge; the
browser uses `localStorage`.

## What exists

- `src/Main.hs`, `src/TimeTrack/{Model,Store,View}.hs` — all app logic in Haskell.
  CPP selects the backend: `-DNATIVE` → Miso native/Lynx; default → browser.
- `timetrack.cabal`, `cabal.project`, `flake.nix`, `flake.lock` — Nix builds:
  - `nix build .#bundle --accept-flake-config -L` → `result/main.lynx.bundle`
  - `nix build .#web --accept-flake-config -L` → static site in `result/`
- `styles.css`, `web/index.html` — shared styling + browser loader.
- `android/` — minimal Lynx host, `NativeLocalStorageModule` Java bridge,
  signing config; keystore at `keystore/timetrack.jks` (password `timetrack`).
- `scripts/build-apk.sh` — bundle + Gradle `assembleRelease` → `dist/timetrack.apk`.
- `.github/workflows/pages.yml` — Pages build/deploy workflow.

## Fixes included in commit `a984531`

1. `flake.nix`: removed the broken `lib.relativeTo` source filter that broke
   every Nix evaluation. Now uses a simple `cleanSourceWith` filter that drops
   `.git`, `.build`, `dist`, `result`, `build`, `.gradle` and `*.log`, plus a
   `postPatch` that removes `cabal.project` from both app derivations.
2. `src/Main.hs`: moved CPP-gated imports above the `app` definition (imports
   after declarations are a Haskell parse error).
3. `src/TimeTrack/Store.hs`: replaced ad-hoc JS FFI with `Miso.Date`
   (`new`, `getHours`, `getMinutes`, `getDate`, `setDate`, `getFullYear`,
   `getMonth`); native calls now use `Miso.Native.Module` with
   `Miso.JSON.Value.String`; web uses `Miso.Storage`.
4. `src/TimeTrack/View.hs`: `textProp` comes from `Miso.Property`, not
   `Miso.Html.Property`.
5. `src/TimeTrack/Model.hs`: Dishes emoji changed to `🧼`.
6. `styles.css`: `.tab-last` now carries the full `.tab` styling (Lynx resolves
   one class token per node).
7. `.gitignore`: added `.build/`.
8. Android host: removed `ThreadStrategyForRendering.ALL_ON_UI` so Lynx keeps
   the BTS/MTS split Miso native requires; Lynx deps bumped to 4.0.3 and the
   full XElement set from Miso's reference host added.
9. Verified against pinned Miso `56c9b2c…`: `nativeEvents`/`nativeXEvents` are
   re-exported by `Miso.Native`; `onInput` receives `InputEvent` with
   `inputValue`; `callNativeModuleWith` decodes a `FromJSON` result via a
   `Either MisoString result` callback; `Miso.Date.setDate :: Int -> Date -> IO Double`.
10. `patches/ghc-9.12-js-ar-darwin-ranlib-padding.patch`: upstream patch that
    trims Apple `ranlib`'s `\n` padding from wasm archive members. Applied to the
    plain cross GHC in `flake.nix` *before* Miso's native overlay adds
    `jsbi.patch`, so no patch is applied twice. This fixed the `wasm-ld: section
    too large` link failure (which also affected Miso's own native sample).

## Current state — DONE

- `nix build .#bundle --accept-flake-config -L` succeeds. All four Haskell
  modules compile; `result/main.lynx.bundle` (9.5 MB) is produced.
- The Darwin `ranlib` padding patch is applied to the *plain* cross GHC, then
  Miso's native overlay adds `jsbi.patch` exactly once on top.
- GHC 9.14.1 and rspeedy were built from source locally (Cachix has no Darwin
  substitutes); ~18 GiB of Nix store space remained afterward.
- `./scripts/build-apk.sh` succeeds: `dist/timetrack.apk` (51 MB) contains
  `assets/main.lynx.bundle` and is signed with the local `timetrack.jks` key.
  Verified with Android build-tools `apksigner verify --verbose --print-certs`:
  **v2 scheme: true**, 1 signer, `CN=TimeTrack`. `jarsigner` reports "jar is not
  signed" only because this APK is v2-only (no v1/META-INF), which is expected.
- GitHub Pages deployment succeeded: run `45345795925`, deployment SHA
  `a984531859e761af7b7c90a182f1ec7a9a78c2cd`. Site verified live at
  https://safrixv.github.io/tt/ — `index.html`, `styles.css`, `all.js` all 200.

## Known environment constraints

- Never run two heavy Nix builds in parallel — that previously filled the disk
  while unpacking `ghc-9.14.1-source`. Build `.#bundle`, then `.#web`,
  sequentially. Scratch dir `/private/tmp/tt-research` was removed.
- Use `--accept-flake-config` (the flake declares the Miso Cachix substituter).
  Local `nix show-config` only has `cache.nixos.org`; Cachix probes 404 on this
  Mac, hence the source build.
- Android: JDK 17, Gradle 8.14.4, AGP 8.5.2, compileSdk 34, build-tools 34.0.0.
  Local Java 26 is too new for Gradle 8; `nix develop .#android` supplies JDK 17.
  Pure Nix APK builds are not realistic because Gradle resolves Maven artifacts.
- Native persistence contract:
  `NativeLocalStorageModule.setStorageItem(key, value)` and
  `getStorageItem(key, callback)`; the Java module is registered globally in
  `TimeTrackApplication.onCreate()`.

## Rebuild / verify commands

```bash
cd /Users/safri/Projects/tt
# Native Android bundle + signed APK (Gradle needs Maven access):
./scripts/build-apk.sh
# APK signature check (build-tools path from nix store):
/nix/store/8pfv3x85ddb3zhw9w0yh79skksmsm18v-android-sdk-build-tools-34.0.0/libexec/android-sdk/build-tools/34.0.0/apksigner verify --verbose --print-certs dist/timetrack.apk
# Redeploy Pages (CI builds .#web with Cachix substitutes):
gh workflow run pages.yml
curl -I https://safrixv.github.io/tt/
# Optional local web verification (heavy: GHCJS builds from source on Darwin):
nix build .#web --accept-flake-config -L
ls -lh result/index.html result/styles.css result/all.js
```

Hosted URL: https://safrixv.github.io/tt/
