# TimeTrack

A dead-simple, fully offline time tracker for Android. Written entirely in
Haskell with [miso](https://haskell-miso.org)'s native (LynxJS) backend.
Nix builds the Haskell code into a `main.lynx.bundle`, which a tiny native
Android host app renders as a standalone APK.

## The idea

Tap a big emoji tile and the activity is logged instantly with the current
time. No menus, no typing. Need more detail? Add a note with the native
keyboard, or edit/delete any entry from the day's log. Everything is stored
on the device; the app never uses the network.

The 16 activities are: Eat, Dishes, Cleaning, Call, Socialize, Read, Coding,
Sleep, Plan, Journal, Socials, Dailies, Laundry, Writing, Walk, Shower.

## Build

Requirements: Nix with flakes enabled. Nothing else.

```bash
# Haskell -> Lynx bundle (also serves for development in Lynx Explorer)
nix build --accept-flake-config # -> result/main.lynx.bundle

# Release APK (signed with the included local-only keystore)
./scripts/build-apk.sh          # -> dist/timetrack.apk
```

Install by copying `dist/timetrack.apk` to your phone and opening it. Android
will ask you to allow installation from unknown sources once.

## Web version

The same Haskell model, update logic and views compile to a browser build with
miso's web backend and are published with GitHub Pages:

**https://safrixv.github.io/tt/**

Build it locally with `nix build .#web --accept-flake-config` (output in `result/`). The
`.github/workflows/pages.yml` workflow rebuilds and deploys the site on every
push to `main`. In the browser, logs are stored in `localStorage`; on Android
they are stored by a small native storage module. Both builds are offline-capable
after the initial load.

## Development

```bash
nix develop .#native             # GHC JavaScript backend, bun, rspeedy
nix develop .#android            # JDK, Gradle, Android SDK
```

Serve the bundle and open it in Lynx Explorer for a fast feedback loop:

```bash
python3 -m http.server 8080 -d result
# point Lynx Explorer at http://<your-ip>:8080/main.lynx.bundle
```

## Layout

- `src/` — the whole application, in Haskell
- `styles.css` — styling for the Lynx views
- `android/` — minimal native host that loads the embedded bundle
- `flake.nix` — Nix toolchain, bundle build, Android dev shell
- `scripts/build-apk.sh` — one-shot release APK build

## Signing

`keystore/timetrack.jks` is a self-signed key generated locally for sideloading
a personal app. Keep it if you want future versions to upgrade cleanly on your
phone. The password is in `android/app/build.gradle`.
