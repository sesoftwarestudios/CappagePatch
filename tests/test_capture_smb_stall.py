from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest


MODULE_PATH = Path(__file__).parents[1] / "tools" / "capture_smb_stall.py"
SPEC = importlib.util.spec_from_file_location("capture_smb_stall", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
capture_smb_stall = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(capture_smb_stall)


def test_build_capture_filter_limits_capture_to_smb_and_host() -> None:
    assert capture_smb_stall.build_capture_filter("192.168.12.202") == (
        "tcp port 445 and host 192.168.12.202"
    )
    assert capture_smb_stall.build_capture_filter(None) == "tcp port 445"


def test_build_tcpdump_command_rotates_truncated_capture(tmp_path: Path) -> None:
    command = capture_smb_stall.build_tcpdump_command(
        interface="en0",
        output_pattern=tmp_path / "smb-%Y%m%d-%H%M%S.pcap",
        host="192.168.12.202",
        snaplen=256,
        segment_seconds=300,
        segments=72,
    )

    assert command[:5] == ["/usr/sbin/tcpdump", "-i", "en0", "-n", "-U"]
    assert "--nano" not in command
    assert command[command.index("-s") + 1] == "256"
    assert command[command.index("-G") + 1] == "300"
    assert command[command.index("-W") + 1] == "72"
    assert command[-1] == "tcp port 445 and host 192.168.12.202"


def test_parse_args_allows_all_smb_hosts_with_empty_host() -> None:
    args = capture_smb_stall.parse_args(["--host", "", "--dry-run"])

    assert args.host is None
    assert args.dry_run is True


def test_parse_args_captures_ipv4_or_ipv6_smb_by_default() -> None:
    args = capture_smb_stall.parse_args(["--dry-run"])

    assert args.host is None
    assert capture_smb_stall.build_capture_filter(args.host) == "tcp port 445"


@pytest.mark.parametrize("snaplen", [0, 128, 159])
def test_parse_args_rejects_snaplen_too_short_for_smb2_headers(snaplen: int) -> None:
    with pytest.raises(SystemExit):
        capture_smb_stall.parse_args(["--snaplen", str(snaplen)])
