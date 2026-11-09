#!/usr/bin/env python3
"""Standalone developer launcher using the same state/commands as Hermes."""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from portals.service import command

parser = argparse.ArgumentParser()
parser.add_argument("--data-dir", type=Path, required=True)
parser.add_argument("command", nargs="*", default=["status"])
args = parser.parse_args()
print(command(args.data_dir.resolve(), " ".join(args.command)))
