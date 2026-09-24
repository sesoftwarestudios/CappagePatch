# CappagePatch modification record

This repository is an independent modified distribution of
[TimeCapsuleSMB](https://github.com/jamesyc/TimeCapsuleSMB). The changes below
were made in September 2026. The complete Git history is retained so each
change remains auditable against its upstream source.

CappagePatch and the modifications documented here were created and are
maintained by [SE Software Studios](https://github.com/sesoftwarestudios).
Benjamin Uitzetter is the project's CEO and Senior Developer.

## Product identity and interface

- Renamed the visible macOS product and application bundle to CappagePatch.
- Added an original CappagePatch icon and a new navy, teal, violet, and amber
  interface system for the sidebar, device overview, status cards, settings,
  and legal-notice view.
- Added a one-click **Recommended for modern macOS** preset for both new-device
  defaults and existing devices. Advanced Samba, AFP, rsync, security, and disk
  timing controls remain available in a collapsed expert section with
  plain-language guidance and risk-focused help text.
- Added an **Older Mac Time Machine** compatibility control for mixed networks.
  It enables the existing Time Capsule AFP Bonjour record and AFP+SMB ADisk
  flag without enabling SMB1 or lowering SMB transport security. Checkup now
  verifies modern SMB remains advertised, then checks the Apple AFP process,
  TCP 548 listener, AFP Bonjour record, and combined Time Machine metadata when
  this mode is enabled.
- Added in-app upstream credit, GPLv3 notice, warranty notice, and trademark
  clarification.
- Preserved the internal `timecapsulesmb` Python module, `tcapsule` helper,
  remote payload paths, Application Support directory, and Keychain service so
  existing installations and saved credentials remain compatible.

## Network-service independence

- Telemetry is disabled by default and has no default endpoint or embedded
  token in this fork.
- Automatic update checks are disabled until a user explicitly configures a
  version metadata URL.
- Upstream project URLs remain only where they provide attribution, historical
  issue context, or documentation.

## Time Capsule runtime correction

- Fixed the no-pthread talloc stack inherited by forked Samba children by
  tracking the owning process ID and resetting inherited state before the
  first child-side allocation.
- Kept the reset idempotent so later child reinitialization does not discard a
  valid stack created by that child.
- Added sanitizer-backed regression coverage for connection children and
  `aio_fork` workers.

This is a root-cause correction for the confirmed allocator-corruption window.
It does not claim that all possible long SMB communication stalls share that
cause. See [SMB_STALL_INVESTIGATION.md](SMB_STALL_INVESTIGATION.md) for the
evidence, remaining hypotheses, and large-backup acceptance gate.

## License

The modified distribution remains licensed under GPL-3.0-only. See
[LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). Bundled third-party components
retain their own notices and licenses.
