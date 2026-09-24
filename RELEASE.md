# CappagePatch Release Verification

CappagePatch releases contain the macOS app bundle, Python CLI, boot scripts,
and checked-in static NetBSD binaries used by deploy. The release process must
make clear which artifacts were shipped, how they were validated, and which
parts remain inherited from TimeCapsuleSMB.

## Samba 4.25.0rc2 candidate

The current Samba build is pinned to `samba-4.25.0rc2`. This brings in upstream
stream parent-directory resolution and AFP_AfpInfo stat fixes. The downstream
series fixes NetBSD stream extent error handling, so deleting a file or directory
with metadata does not fail after removing only its primary stream. It also
preserves lookup and I/O failures instead of reporting false success.

The existing NetBSD SDKs are retained. A const-preserving charset fallback
supports their older GCC versions, and the embedded srvsvc and durable-cookie
patches are adapted to rc2's APIs. `streams_xattr:max xattrs per stream = 2`
remains necessary with this release candidate.

Before switching to 4.25 final, reapply the series to the final tag, check whether
the extent fix is incorporated upstream, and repeat the Samba regression and
macOS mounted-share checks documented in `tests/samba/README.md`.

## Release Assets

The primary user-facing release asset is `CappagePatch.app.zip` on the GitHub
release page. GitHub shows the SHA256 digest for uploaded release assets in the
asset metadata. Users can verify a downloaded app zip with:

```bash
shasum -a 256 CappagePatch.app.zip
```

The digest printed by `shasum` should match the `sha256:` value shown for the asset on GitHub.

## Checked-In Device Artifacts

The deploy flow uses the binaries checked into `bin/`:

| Device family | Samba binary | mDNS binary | NBNS binary |
| --- | --- | --- | --- |
| NetBSD 6 / 7 | `bin/samba4/smbd` | `bin/mdns/mdns-advertiser` | `bin/nbns/nbns-advertiser` |
| NetBSD 4 little-endian | `bin/samba4-netbsd4le/smbd` | `bin/mdns-netbsd4le/mdns-advertiser` | `bin/nbns-netbsd4le/nbns-advertiser` |
| NetBSD 4 big-endian | `bin/samba4-netbsd4be/smbd` | `bin/mdns-netbsd4be/mdns-advertiser` | `bin/nbns-netbsd4be/nbns-advertiser` |

Every checked-in device artifact must have a matching entry in `src/timecapsulesmb/assets/artifact-manifest.json`. The manifest stores the repo-relative path and SHA256 digest used by deploy-time validation.

Before tagging a release, run:

```bash
.venv/bin/pytest tests/test_artifacts.py tests/test_artifact_resolver.py
```

For a full local release check, run:

```bash
make test
swift test --package-path macos/TimeCapsuleSMB
python3 macos/TimeCapsuleSMB/tools/package_app.py \
  --configuration release --arch universal --zip --full-validation
```

Before publishing a universal archive, verify the app executable, helper,
embedded Python runtime, `sshpass`, `smbclient`, and every bundled non-system
dylib contain both `arm64` and `x86_64` support where applicable. The package
validator performs this check; do not relabel a native-only test ZIP as a
universal release.

When an architecture-specific tool comes from a verified package archive
rather than a system installation, point the packager at the tool and its
unpacked dependency root. For example:

```bash
TCAPSULE_PACKAGE_SMBCLIENT_X86_64=/path/to/root/opt/local/bin/smbclient \
TCAPSULE_PACKAGE_DEPENDENCY_ROOT_X86_64=/path/to/root \
python3 macos/TimeCapsuleSMB/tools/package_app.py \
  --configuration release --arch universal --zip --full-validation
```

The dependency overlay is selected only for Mach-O files of the matching
architecture. Full validation still rejects missing slices, external library
references, or invalid signatures.

## Tested A1470 release candidate

The September 22-23, 2026 candidate completed the following checks on an A1470
(`TimeCapsule8,119`):

- corrected Checkup with simultaneous SMB and AFP Bonjour advertisements;
- authenticated SMB listing and file-operation checks;
- one fresh full macOS 26 Time Machine backup and subsequent SMB backups; and
- one completed OS X Lion AFP backup while macOS 26 SMB backups remained
  functional.

The Lion progress display changed once in a way that might have represented a
resume, but no disconnect or backup error was observed. Release notes must call
that an unconfirmed interruption, not a reproduced defect or a cleanly measured
network outage.

## NetBSD Builds

When a change touches `build/`, rebuild the affected NetBSD artifact before release. Do not rebuild the NetBSD toolchains unless that is the explicit task. After a successful root build on the VM, copy the stripped binary back into `bin/`, wait a few seconds for filesystem state to settle, then update `src/timecapsulesmb/assets/artifact-manifest.json`.

For mDNS and NBNS advertisers, run the helper scripts from the repo root on the NetBSD VM:

```bash
./build/mdns.sh && ./build/mdnsoldle.sh && ./build/mdnsoldbe.sh && ./build/nbns.sh && ./build/nbnsoldle.sh && ./build/nbnsoldbe.sh
```

For Samba 4.x, build and validate one lane first when changing Samba source or build logic:

```bash
./build/downloadsamba4x.sh && ./build/samba4x.sh
./build/downloadsamba4xoldle.sh && ./build/samba4xoldle.sh
./build/downloadsamba4xoldbe.sh && ./build/samba4xoldbe.sh
```

Do not run underscore-prefixed helper scripts directly.

## Signing And Notarization

The macOS app packaging flow supports Developer ID signing and notarization when the relevant signing environment is configured. A public release should state whether the attached app zip is notarized. When notarization is enabled, the package validation step should complete successfully before the release asset is uploaded.

## Release Checklist

- Update `version.json` and `pyproject.toml` to the release version.
- Rebuild any changed NetBSD artifacts and update `artifact-manifest.json`.
- Run the artifact manifest tests.
- Run the Python and Swift test suites.
- Package and validate the macOS app.
- Confirm `README.md`, `CAPPAGEPATCH_CHANGES.md`, and
  `SMB_STALL_INVESTIGATION.md` describe the tested behavior without overstating
  the result.
- Confirm the universal package contains working tools for both architectures.
- Upload `CappagePatch.app.zip` to the GitHub release.
- Confirm the uploaded asset SHA256 digest is visible on GitHub.
- Include user-facing release notes with compatibility or flash-safety warnings when applicable.
