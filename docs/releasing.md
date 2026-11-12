# Releasing

For maintainers. Merging to `main` publishes nothing; a release is a separate step. Versions follow
[Semantic Versioning](https://semver.org), `0.x` for now: new features raise the minor number, fixes only the
patch number.

Work on a branch of its own, such as `release-0.4.0`.

1. **Version.** In `app/export_presets.cfg`, set the new number (`version/name="0.4.0"`) and raise the version
   code by one (`version/code=4`). Check the package name is still `package/unique_name="app.cartouche"`.
2. **Changelog.** In `CHANGELOG.md`, rename the Unreleased section to the version and its day
   (`## [0.4.0] - 2026-12-01`) and add an empty Unreleased above it. Sections follow
   [Keep a Changelog](https://keepachangelog.com), in sentences a player understands. Link issues with relative
   links (`../../issues/<number>`) and thank their reporters.
3. **Media.** If the look changed, replace the clips of `docs/media/`: short animated WebP files of the demo
   library, at real speed.
4. **Full check.** `scripts/build.sh`. Its `scripts/check_release.sh` exports a release pack, fails if any file of
   `app/dev/bridge/` is in it (INV-24), then starts it and fails on a script error or unless the carousel is
   restored on a game. If the release touches something measured, run the
   [benchmarks](device-testing.md#benchmarks) and compare with the last release.
5. **The engine template.** Build it if its fingerprint changed (`scripts/godot_template.sh build`): an export
   without it uses Godot's official template, which has no R8. Record the pipeline list again if what the app
   draws changed ([the engine template](README.md#the-engine-template)).
6. **Release APK.** Signed with the project's release key, read from the environment. The key never changes: a
   new one would stop every installed copy from updating. The build must also hold ScreenScraper's developer key
   ([credentials](../CONTRIBUTING.md#credentials)).

   ```sh
   cd kotlin && ./gradlew :android:assemble && cd ..
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.keystore
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=cartouche
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
   scripts/export_apk.sh release build/cartouche-X.Y.Z.apk      # its first line names the engine template used
   $ANDROID_HOME/build-tools/36.1.0/apksigner verify --print-certs build/cartouche-X.Y.Z.apk
   ```

7. **Try it as an update.** `adb install -r` over the previous release, and check the library, settings and chosen
   labels are still there.
8. **Commit and merge.** One commit, `Cartouche X.Y.Z: <what is new, in a phrase>`, merged to `main`.
9. **Publish.** Push `main`, tag, and create the GitHub release with the APK, its notes the version's section of
   `CHANGELOG.md`:

   ```sh
   git tag vX.Y.Z && git push origin vX.Y.Z
   gh release create vX.Y.Z build/cartouche-X.Y.Z.apk --title "Cartouche X.Y.Z" --notes-file build/notes.md
   ```

10. **Tell the reporters.** Comment the release's link on each issue it fixes.
