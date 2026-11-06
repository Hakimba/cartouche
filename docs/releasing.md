# Releasing

**You are here.** How a maintainer publishes a version of Cartouche: its number, its changelog, its signed APK and
its GitHub release. Merging to `main` publishes nothing; a release is a separate, deliberate step. Contributors do
not need this page.

## The number

Versions follow [Semantic Versioning](https://semver.org), `0.x` while the app is young:

- a release with new features raises the minor number (`0.3.0` to `0.4.0`);
- a release with fixes only raises the patch number (`0.3.0` to `0.3.1`).

## Steps

Work on a branch of its own, such as `release-0.4.0`.

1. **Version.** In `app/export_presets.cfg`, set the new number (`version/name="0.4.0"`) and raise the version code
   by one (`version/code=4`). Check that the package name is still `package/unique_name="app.cartouche"`.
2. **Changelog.** In `CHANGELOG.md`, rename the Unreleased section to the version and its day
   (`## [0.4.0] - 2026-12-01`), and add a new, empty Unreleased section above it. Sections follow [Keep a Changelog](https://keepachangelog.com) (Added, Changed,
   Removed, Fixed), in sentences a user understands. Link issues with relative links (`../../issues/<number>`), and
   thank the people who reported them.
3. **Media.** If the look changed, replace the clips of `docs/media/`: short animated WebP files cut from the demo
   library, at real speed.
4. **Full check.** `scripts/build.sh` runs every test once, and `scripts/check_release.sh` among them: it exports a
   release pack and fails if any file of the debug bridge (`app/dev/bridge/`) is in it (INV-24). If the release
   touches something measured, run `scripts/bench.sh` at several sizes and compare with the last release
   ([device-testing.md](device-testing.md#benchmarks)).
5. **Release APK.** Build the plugin, then export a release signed with the project's release key. Godot reads the
   key from environment variables; the key and its password are kept by the maintainers, outside the repository,
   and never change (a new key would stop every installed copy from updating).

   ```sh
   cd kotlin && ./gradlew :android:assemble && cd ..
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.keystore
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=cartouche
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
   $GODOT --headless --path app --export-release Android ../build/cartouche-X.Y.Z.apk
   $ANDROID_HOME/build-tools/36.1.0/apksigner verify --print-certs build/cartouche-X.Y.Z.apk
   ```

   The build must also hold ScreenScraper's developer key (`kotlin/local.properties`, see
   [Credentials](README.md#credentials)): without it, the app finds no ScreenScraper image.
6. **Try it as an update.** Install the new APK over the previous release on a device (`adb install -r`), as users
   will get it, and check that the library, settings and chosen labels are still there.
7. **Commit and merge.** One commit, its subject like `Cartouche X.Y.Z: <what is new, in a phrase>`, merged to
   `main`.
8. **Publish.** Push `main`, tag the commit and create the GitHub release with the APK, its notes being the
   version's section of `CHANGELOG.md`:

   ```sh
   git tag vX.Y.Z && git push origin vX.Y.Z
   gh release create vX.Y.Z build/cartouche-X.Y.Z.apk --title "Cartouche X.Y.Z" --notes-file build/notes.md
   ```

9. **Tell the reporters.** Comment the release's link on each issue it fixes.

## Neighbours

- [CONTRIBUTING.md](../CONTRIBUTING.md): what a change needs before it is merged.
- [device-testing.md](device-testing.md): installing and measuring on a device.
- Back to the entry: [README.md](README.md).
