# TimeTrack — handoff / resume notes

_Last saved: 2026-11-24. Git repo is on `main`, pushed to
`git@github.com:SafriXV/tt.git`. GitHub Pages is enabled with
`build_type=workflow`; `.github/workflows/pages.yml` deploys `result/` from
`nix build .#web`._

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

## Fixes made since the last pushed commit

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

## Current state

- `nix build .#bundle --accept-flake-config -L` **succeeds**. All four Haskell
  modules compile; `result/main.lynx.bundle` (9.5 MB) is produced.
- The Darwin `ranlib` padding patch is applied to the *plain* cross GHC, then
  Miso's native overlay adds `jsbi.patch` exactly once on top.
- GHC 9.14.1 and rspeedy were built from source locally (Cachix has no Darwin
  substitutes), so only ~18 GiB of Nix store space remained afterward.
- No `dist/timetrack.apk` yet. Web build and Pages deployment are pending.

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

## Resume checklist

```bash
cd /Users/safri/Projects/tt
# 1. Commit and push the fixes:
git add -A && git commit -m "Fix Miso APIs, Nix eval, Darwin GHC link, and Android host" && git push
# 2. Produce the APK (bundle is already built; Gradle needs Maven access):
./scripts/build-apk.sh
# 3. Deploy Pages (CI builds .#web with Cachix substitutes) and verify:
gh workflow run pages.yml
curl -I https://safrixv.github.io/tt/
# 4. Optional local web verification (heavy: GHCJS builds from source on Darwin):
nix build .#web --accept-flake-config -L
ls -lh result/index.html result/styles.css result/all.js
```

Hosted URL (once the workflow succeeds): https://safrixv.github.io/tt/
