#!/usr/bin/env python3
"""Capture enough macOS evidence to locate an intermittent SMB stall.

The packet capture is deliberately truncated to protocol headers.  It is meant
to establish whether an SMB request left the Mac and whether the matching
response returned, not to collect file contents from a Time Machine backup.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shlex
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence


DEFAULT_INTERFACE = "en0"
DEFAULT_HOST: str | None = None
DEFAULT_SNAPLEN = 256
DEFAULT_SEGMENT_SECONDS = 300
DEFAULT_SEGMENTS = 72
DEFAULT_SAMPLE_SECONDS = 5.0


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def build_capture_filter(host: str | None) -> str:
    if host:
        return f"tcp port 445 and host {host}"
    return "tcp port 445"


def build_tcpdump_command(
    *,
    interface: str,
    output_pattern: Path,
    host: str | None,
    snaplen: int,
    segment_seconds: int,
    segments: int,
) -> list[str]:
    return [
        "/usr/sbin/tcpdump",
        "-i",
        interface,
        "-n",
        "-U",
        "-B",
        "4096",
        "-s",
        str(snaplen),
        "-G",
        str(segment_seconds),
        "-W",
        str(segments),
        "-w",
        str(output_pattern),
        build_capture_filter(host),
    ]


def build_log_stream_command() -> list[str]:
    predicate = (
        'process == "backupd" OR process == "diskimagesiod" OR '
        '(process == "kernel" AND '
        '(eventMessage CONTAINS[c] "smb" OR eventMessage CONTAINS[c] "timeout" OR '
        'eventMessage CONTAINS[c] "disconnect"))'
    )
    return [
        "/usr/bin/log",
        "stream",
        "--style",
        "compact",
        "--level",
        "info",
        "--predicate",
        predicate,
    ]


def run_snapshot_command(command: Sequence[str], *, timeout: float = 10.0) -> dict[str, object]:
    started = time.monotonic()
    try:
        result = subprocess.run(
            list(command),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        return {
            "argv": list(command),
            "returncode": result.returncode,
            "elapsed_seconds": round(time.monotonic() - started, 3),
            "output": result.stdout,
        }
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        return {
            "argv": list(command),
            "returncode": None,
            "elapsed_seconds": round(time.monotonic() - started, 3),
            "timed_out": True,
            "output": output,
        }
    except OSError as exc:
        return {
            "argv": list(command),
            "returncode": None,
            "elapsed_seconds": round(time.monotonic() - started, 3),
            "error": str(exc),
            "output": "",
        }


def snapshot_commands(interface: str, host: str | None) -> list[list[str]]:
    commands = [
        ["/usr/bin/tmutil", "status"],
        ["/usr/sbin/netstat", "-anv", "-p", "tcp"],
        ["/sbin/ifconfig", interface],
        ["/sbin/mount"],
    ]
    if host:
        commands.append(["/sbin/route", "-n", "get", host])
    return commands


def write_metadata(output_dir: Path, args: argparse.Namespace, tcpdump_command: Sequence[str]) -> None:
    metadata = {
        "created_at": utc_now(),
        "platform": platform.platform(),
        "python": sys.version,
        "effective_uid": os.geteuid(),
        "interface": args.interface,
        "host_filter": args.host,
        "snaplen": args.snaplen,
        "segment_seconds": args.segment_seconds,
        "segments": args.segments,
        "sample_seconds": args.sample_seconds,
        "tcpdump_argv": list(tcpdump_command),
        "privacy": (
            "Capture is limited to TCP port 445 and truncated to the configured snap length. "
            "SMB/TCP headers and a small leading portion of each packet may still be present."
        ),
    }
    (output_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def sample_state(
    *,
    output_path: Path,
    interface: str,
    host: str | None,
    interval: float,
    stop_event: threading.Event,
) -> None:
    commands = snapshot_commands(interface, host)
    with output_path.open("a", encoding="utf-8") as stream:
        while not stop_event.is_set():
            sample = {
                "captured_at": utc_now(),
                "commands": [run_snapshot_command(command) for command in commands],
            }
            stream.write(json.dumps(sample, sort_keys=True) + "\n")
            stream.flush()
            stop_event.wait(interval)


def start_logged_process(command: Sequence[str], output_path: Path) -> tuple[subprocess.Popen[str], object]:
    stream = output_path.open("a", encoding="utf-8")
    process = subprocess.Popen(
        list(command),
        text=True,
        stdout=stream,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    return process, stream


def stop_process(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGINT)
        process.wait(timeout=8)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=3)
            except (ProcessLookupError, subprocess.TimeoutExpired):
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=3)


def default_output_dir() -> Path:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return Path.cwd() / "diagnostics" / f"smb-stall-{stamp}"


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Capture header-only SMB traffic and macOS Time Machine state around a stall."
    )
    parser.add_argument("--interface", default=DEFAULT_INTERFACE)
    parser.add_argument(
        "--host",
        default=DEFAULT_HOST,
        help=(
            "Optional IP-address filter. By default all TCP/445 traffic is captured so "
            "a Bonjour-selected link-local IPv6 connection is not missed."
        ),
    )
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--snaplen", type=int, default=DEFAULT_SNAPLEN)
    parser.add_argument("--segment-seconds", type=int, default=DEFAULT_SEGMENT_SECONDS)
    parser.add_argument("--segments", type=int, default=DEFAULT_SEGMENTS)
    parser.add_argument("--sample-seconds", type=float, default=DEFAULT_SAMPLE_SECONDS)
    parser.add_argument(
        "--duration-seconds",
        type=float,
        default=0.0,
        help="Stop automatically after this many seconds; zero runs until interrupted.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the tcpdump command without creating files or requesting sudo.",
    )
    args = parser.parse_args(argv)
    if args.snaplen < 160:
        parser.error("--snaplen must be at least 160 bytes to retain IPv6/TCP/SMB2 headers")
    if args.segment_seconds <= 0 or args.segments <= 0 or args.sample_seconds <= 0:
        parser.error("segment count, segment duration, and sample interval must be positive")
    if args.duration_seconds < 0:
        parser.error("--duration-seconds cannot be negative")
    if args.host is not None:
        args.host = args.host.strip() or None
    return args


def ensure_root(argv: Sequence[str]) -> None:
    if os.geteuid() == 0:
        return
    command = ["/usr/bin/sudo", sys.executable, str(Path(__file__).resolve()), *argv]
    print("Packet capture needs administrator access. Running:", shlex.join(command), flush=True)
    os.execv(command[0], command)


def run(argv: Sequence[str] | None = None) -> int:
    raw_argv = list(sys.argv[1:] if argv is None else argv)
    args = parse_args(raw_argv)
    output_dir = (args.output or default_output_dir()).expanduser().resolve()
    capture_pattern = output_dir / "smb-%Y%m%d-%H%M%S.pcap"
    tcpdump_command = build_tcpdump_command(
        interface=args.interface,
        output_pattern=capture_pattern,
        host=args.host,
        snaplen=args.snaplen,
        segment_seconds=args.segment_seconds,
        segments=args.segments,
    )

    if args.dry_run:
        print(shlex.join(tcpdump_command))
        return 0

    if platform.system() != "Darwin":
        raise SystemExit("This collector currently supports macOS only.")
    ensure_root(raw_argv)

    output_dir.mkdir(parents=True, exist_ok=False)
    write_metadata(output_dir, args, tcpdump_command)
    stop_event = threading.Event()
    sampler = threading.Thread(
        target=sample_state,
        kwargs={
            "output_path": output_dir / "state.jsonl",
            "interface": args.interface,
            "host": args.host,
            "interval": args.sample_seconds,
            "stop_event": stop_event,
        },
        name="smb-state-sampler",
        daemon=True,
    )

    processes: list[tuple[subprocess.Popen[str], object]] = []
    try:
        processes.append(start_logged_process(tcpdump_command, output_dir / "tcpdump.log"))
        processes.append(start_logged_process(build_log_stream_command(), output_dir / "macos.log"))
        sampler.start()
        print(f"Capture directory: {output_dir}")
        print("Capture is active. Start or continue the Time Machine backup.")
        print("Leave this running through a stall, then press Control-C.")

        deadline = time.monotonic() + args.duration_seconds if args.duration_seconds else None
        while not stop_event.wait(1.0):
            failed = [process for process, _stream in processes if process.poll() not in (None, 0)]
            if failed:
                print("A capture subprocess exited unexpectedly; stopping.", file=sys.stderr)
                return 2
            if deadline is not None and time.monotonic() >= deadline:
                break
    except KeyboardInterrupt:
        print("Stopping capture...")
    finally:
        stop_event.set()
        for process, _stream in processes:
            stop_process(process)
        for _process, stream in processes:
            stream.close()
        sampler.join(timeout=max(15.0, args.sample_seconds + 10.0))

    print(f"Capture complete: {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
