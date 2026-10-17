# Release process

1. Review the code and run `zsh scripts/check-engine.sh` and `swift test` (full Xcode required for XCTest). Check that the GitHub macOS workflow passes.
2. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`, the changelog and the README's version-specific download name.
3. If artwork changes, run `zsh scripts/build-icon.sh`. Commit `assets/AppIcon.icns`, `assets/AppIcon.png` and the renderer source.
4. Run `zsh scripts/package-release.sh`. It stages a fresh app bundle, strips local debug/source paths from the executable, signs it ad hoc, verifies the signature, and creates `dist/release/Lid-Duck-VERSION-macos-ARCH.zip` with a `.sha256` checksum. The architecture is read from the executable, not assumed.
5. Verify the archive by extracting it to a temporary folder and running `codesign --verify --strict` on the extracted app. Inspect archive contents so only the app bundle is included.
6. Commit and push the reviewed source. Create the version tag at that exact commit and upload the ZIP plus checksum to its GitHub release. Keep generated build output out of the source tree.
7. In release notes, state macOS/hardware/architecture requirements, installation steps, Gatekeeper/signing status and manual validation gaps. Do not label an ad-hoc signed build as notarized or Developer ID signed.

The existing local build does not use Apple signing credentials, upload to Apple's notary service, enable automatic updates, or register login items. It only packages the app. The installed app's login registration remains opt-in.

For broader distribution, replace ad-hoc signing with Developer ID signing, hardened runtime and a secure timestamp, then notarize, staple and verify the downloadable artifact on a clean Mac. Keep signing credentials out of source control.

No source-code license has been selected. Do not describe the project as open source until one is added.
