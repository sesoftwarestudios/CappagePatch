# SMB stall and allocator-crash investigation

## Confirmed fork-child allocator defect

The A1470 appliance build disables pthreads, so Samba's talloc stack tracking is
process-global.  A newly forked connection child inherits the parent event
loop's active stack.  In `smbd_accept_connection()`, that child calls
`talloc_move()` and `talloc_free(s->parent)` before it calls
`smbd_reinit_after_fork()`.  Patch 0022 previously reset the inherited stack
inside `smbd_reinit_after_fork()`, after those first child-side talloc calls.

The released `smbd` crash address resolves to the return from
`talloc_free(s->parent)` in this pre-reinitialization window.  The fix resets
the copied stack immediately in the `pid == 0` branch, before any child talloc
operation.  The reset inside `smbd_reinit_after_fork()` is also moved before
generic reinitialization because that routine can allocate.  The raw
`aio_fork` worker already has its own immediate reset because it does not pass
through `smbd_reinit_after_fork()`.

The no-pthread stack now records its owning process ID.  This makes the reset
idempotent: the first child-side call drops a stack inherited from the parent,
while a later call in the same child preserves any new stack that child has
already created.

This is a root-cause correction for the allocator crash during connection-child
creation.  It does not, by itself, prove that every observed 62- or 120-second
network silence has the same cause.

The no-pthread AIO regression now creates a fresh stack in the forked child,
calls the reset function a second time (matching the connection-child sequence),
and verifies that the fresh stack is preserved.  With the former unconditional
reset this assertion fails; with the PID-ownership guard the complete `all`
scenario passes under AddressSanitizer and UndefinedBehaviorSanitizer.

## Remaining SMB silence investigation

The open failure cannot be classified as an HFS blocking bug from Samba logs
alone.  Existing debug logs show Samba completing each request it receives,
followed by silence until the macOS SMB response timeout expires.  A packet
capture is required to distinguish these cases:

1. macOS did not transmit the next request;
2. the request left macOS but did not reach the Time Capsule;
3. Samba or the NetBSD TCP path did not transmit the response; or
4. the response left the Time Capsule but did not return to macOS.

The published failing connection and the current A1470 test connection both use
IPv6.  The first controlled comparison is therefore the existing IPv6 Bonjour
path versus a forced IPv4 path.  This is a hypothesis, not yet a fix.

The first header-only capture on the test A1470 covered a successful incremental
backup, not a failure.  It contained 1,562,414 SMB packets across three capture
segments (two busy five-minute segments and a short post-backup segment).  The
largest packet-to-packet gap was 7.51 seconds; no
62- or 120-second silence occurred.  macOS logged repeated Wi-Fi `Datapath
timeout on en0` messages during that successful run, so those messages alone
must not be treated as proof that a backup failure is in the Wi-Fi driver.  A
capture that spans an actual failure is still required to classify issue #294.

## macOS capture

Run this from the repository root in a terminal.  It asks for administrator
authorization because macOS restricts packet capture:

```sh
python3 tools/capture_smb_stall.py \
  --interface en0
```

The collector rotates five-minute pcap files, retains up to six hours, records
Time Machine/socket/interface state every five seconds, and streams relevant
macOS logs.  Packet snapshots are truncated to 256 bytes.  This retains the
IPv6, TCP, NetBIOS and SMB2 headers needed for sequencing while excluding the
body of normal backup writes.

The default intentionally captures all TCP/445 traffic because Bonjour selects
the A1470's link-local IPv6 address in the observed failure path.  Use `--host`
only with the exact address shown by `netstat` during the backup.

Start or continue a Time Machine backup after the collector reports that it is
active.  Leave it running through a failure and stop it with Control-C.  Do not
delete or repair the backup before the capture is preserved.

## Acceptance gate

A root-cause patch must meet all of these conditions:

- identify the missing request or response at both packet and Samba-log level;
- explain why the failure occurs without relying only on elapsed-time
  correlation;
- contain a regression test that fails when the defect is restored;
- avoid making `aio_fork` the default while its worker-creation allocator crash
  remains unresolved; and
- complete repeated large Time Machine backup runs on the affected A1470,
  including at least one clean full backup and subsequent incremental backups.

One uninterrupted backup is useful evidence but is not sufficient to declare
the defect fixed.
