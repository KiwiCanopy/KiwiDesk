#!/usr/bin/env python3
"""Sum swift-frontend CPU per module from a `-stats-output-dir`.

Usage: python3 -I frontend-cpu.py <stats-dir> [--key user|sys|wall]

Reads every JSON file the build wrote with
`-Xswiftc -stats-output-dir -Xswiftc <dir>` and sums the
`time.swift-frontend.<module>-*.<key>` values per module, largest
first. `user` (the default) is frontend CPU seconds, the number to
compare across builds; `wall` overlaps across parallel jobs and
does not sum to the build's wall time.
"""
import argparse
import collections
import json
import pathlib

PREFIX = "time.swift-frontend."


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("stats_dir")
    parser.add_argument("--key", choices=("user", "sys", "wall"),
                        default="user")
    args = parser.parse_args()
    total, jobs = collections.Counter(), collections.Counter()
    files = sorted(pathlib.Path(args.stats_dir).glob("*.json"))
    for path in files:
        for name, value in json.loads(path.read_text()).items():
            if name.startswith(PREFIX) and name.endswith("." + args.key):
                module = name[len(PREFIX):].split("-", 1)[0]
                total[module] += value
                jobs[module] += 1
    print(f"== frontend {args.key} seconds over {len(files)} files")
    for module, seconds in total.most_common():
        print(f"{seconds:9.1f}  {module}  ({jobs[module]} jobs)")


if __name__ == "__main__":
    main()
