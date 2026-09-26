# CappagePatch 3.1.2

This recovery release adds a guarded **Reset Time Machine Connection** action
to the verified-install screen. It is intended for the specific case where
macOS keeps returning `BACKUP_FAILED_DISK_IMAGE_NOT_MOUNTED (21)` after the
Time Capsule-side update has already completed.

- The action checks `tmutil status` and refuses to run while a backup is active.
- It explains the operation and requires explicit confirmation plus the normal
  macOS administrator authorization dialog.
- It restarts only the local `backupd-helper` and `backupd` processes. Launchd
  recreates them on demand.
- It never deletes, renames, repairs, mounts, or rewrites a sparsebundle or any
  other backup data.
- The complete recovery interface is localized in every language supported by
  CappagePatch.

The recovery was derived from a reproduced macOS 26 case: the pre-update
`backupd` process retained a failed sparsebundle attachment after repeated
band `0` `EBUSY` errors. After resetting the local services, a fresh process
mounted the same backup, completed an incremental backup, synchronized its
result files, and unmounted cleanly.

## CappagePatch 3.1.1

This patch release makes Samba's required Time Machine locking profile
explicit on every generated backup share:

- durable handles remain enabled;
- kernel oplocks and kernel share modes remain disabled; and
- POSIX locking is disabled so SMB byte-range locks are not mirrored into
  stale host locks on the Time Capsule's HFS volume.

The change addresses a reproduced post-disconnect failure in which macOS could
list and read the sparsebundle but repeatedly failed to reopen band `0` with
`EBUSY`, eventually reporting `BACKUP_FAILED_DISK_IMAGE_NOT_MOUNTED (21)`.
Existing backups are preserved. AFP service and Older Mac Support are not
changed, so legacy AFP and modern SMB clients can continue to coexist.

## CappagePatch 3.1.0

**[Download CappagePatch.app.zip](https://github.com/sesoftwarestudios/CappagePatch/releases/download/v3.1.0/CappagePatch.app.zip)**

The app download is the release asset named `CappagePatch.app.zip`; GitHub's
automatically generated **Source code** archives are not the macOS app.

CappagePatch 3.1.0 is the first public CappagePatch release. It is an
independent GPL-3.0-only modified distribution of TimeCapsuleSMB, retaining the
upstream copyright, license, and Git history.

## Highlights

- Fixes the confirmed no-pthread talloc corruption window after Samba forks by
  resetting inherited allocator state in the child process.
- Adds an **Older Mac Support** mode that advertises AFP for legacy Time
  Machine clients without disabling or downgrading SMB for modern macOS.
- Adds recommended presets and plain-language guidance while keeping advanced
  controls available to experienced users.
- Rebrands the macOS management app and interface as CappagePatch.
- Ships a universal macOS 14+ management app for Apple-silicon and Intel Macs.

## Tested configuration

The release candidate was deployed to an A1470 (`TimeCapsule8,119`):

- a fresh full macOS 26 Time Machine backup completed in one run over SMB;
- subsequent macOS 26 SMB backups completed;
- an OS X Lion 59 GB Time Machine backup completed over AFP while modern SMB
  remained operational;
- authenticated SMB listing and create/read/rename/copy/delete checks passed;
  and
- simultaneous SMB and AFP Bonjour advertisements passed Checkup and direct
  inspection.

Lion displayed one progress change that might have represented a resume, but
there was no explicit disconnect or backup error. This is recorded as an
unconfirmed interruption, not a demonstrated failure.

## Installation

1. [Download `CappagePatch.app.zip`](https://github.com/sesoftwarestudios/CappagePatch/releases/download/v3.1.0/CappagePatch.app.zip)
   and verify its SHA-256 digest against the value shown on the GitHub release.
2. Unzip the app.
3. Because this community build is ad-hoc signed and not Apple-notarized,
   control-click the app in Finder and choose **Open**. If macOS still blocks
   it, use **System Settings > Privacy & Security > Open Anyway**. Do not
   disable Gatekeeper system-wide.
4. Grant Local Network access when macOS asks, then follow the in-app setup.

The management app requires macOS 14 or later. Older Macs do not run the app;
after **Older Mac Support** is enabled, they use the Time Capsule's AFP Time
Machine destination normally.

## Important notes

- Existing backup data is not intentionally deleted or reformatted by the
  installation flow, but keep independent backups before modifying appliance
  firmware or storage configuration.
- This release corrects the confirmed allocator-corruption cause. It does not
  claim that every possible network interruption or disk failure has the same
  cause.
- CappagePatch is provided without warranty under GPL-3.0-only. Apple, AirPort,
  Time Capsule, Time Machine, and macOS are Apple trademarks; this project is
  not affiliated with or endorsed by Apple.

## Verification

- 1,902 Python tests and 219 subtests passed.
- 535 Swift tests passed.
- Native Apple-silicon and Rosetta Intel smoke checks passed.
- Full package architecture, dependency, and signature validation passed.

`CappagePatch.app.zip` (128 MiB):

```text
SHA256 1f97c2687498acc4fda9ac80b117f82abbc24409ff5bd46e06e9e77f8dd00c33
```
