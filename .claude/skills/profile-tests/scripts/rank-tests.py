#!/usr/bin/env python3
"""Rank suites and tests by time from a Swift Testing event stream.

Usage: python3 -I rank-tests.py <events.jsonl> [--top N]
                                [--only suites|tests]

Reads the stream `swift test --event-stream-output-path <f>
--event-stream-version 0` writes and prints, longest first, the
seconds from each `testStarted` to its `testEnded`, suites and tests
in separate tables. Only a `--no-parallel` run gives cost: in a
parallel run a test's span includes its wait for the main actor
(median 13 s per test in Core, 55 s in GUI, measured 2026-11-07).
"""
import argparse
import collections
import json


def spans(path):
    """Return ({testID: seconds}, {testID: kind}) for one stream."""
    started, total, kind = {}, collections.Counter(), {}
    with open(path) as stream:
        for line in stream:
            record = json.loads(line)
            payload = record.get("payload", {})
            if record.get("kind") == "test":
                kind[payload.get("id")] = payload.get("kind")
                continue
            if record.get("kind") != "event":
                continue
            event, test = payload.get("kind"), payload.get("testID")
            stamp = payload["instant"]["absolute"]
            if event == "testStarted":
                started[test] = stamp
            elif event == "testEnded" and test in started:
                total[test] += stamp - started.pop(test)
    return total, kind


def is_suite(test, kind):
    """A suite by its record, else by its ID carrying no `/`."""
    if test in kind:
        return kind[test] == "suite"
    return "/" not in test


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("events")
    parser.add_argument("--top", type=int, default=20)
    parser.add_argument("--only", choices=("suites", "tests"))
    args = parser.parse_args()
    total, kind = spans(args.events)
    for label in ("suites", "tests"):
        if args.only and args.only != label:
            continue
        rows = [(seconds, test) for test, seconds in total.items()
                if is_suite(test, kind) == (label == "suites")]
        rows.sort(reverse=True)
        print(f"== {label}: {len(rows)}, "
              f"{sum(s for s, _ in rows):.1f} s in all")
        for seconds, test in rows[:args.top]:
            print(f"{seconds:8.2f}  {test}")


if __name__ == "__main__":
    main()
