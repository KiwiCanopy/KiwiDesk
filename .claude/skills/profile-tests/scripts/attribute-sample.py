#!/usr/bin/env python3
"""Attribute a `sample` capture of a test helper.

Usage: attribute-sample.py <sample.txt> [--module KiwiDeskCoreTests]

Prints, for the MAIN thread: how many samples it spent blocked in
mach_msg (waiting on another process, usually WindowServer) versus
running, the outermost WindowServer entry points it waited in, and
the innermost frames of the test module above each wait. Then, for
ALL threads, the busiest innermost test-module frames by CPU
samples (blocked leaves excluded). The first half answers "what is
it waiting on", the second "where does the CPU go" (#1868).
"""
import collections
import re
import sys

IDLE = ("mach_msg", "__workq_kernreturn", "__psynch", "semwait", "read")
WS = re.compile(r"(SLS|CGS|_SLS|_CGS|_NX|CGMain|CGDisplay)")


def threads(lines):
    starts = [i for i, l in enumerate(lines)
              if re.match(r"^\s{4}\d+ Thread_", l)]
    end = next(i for i, l in enumerate(lines)
               if l.startswith("Total number in stack"))
    for n, s in enumerate(starts):
        e = starts[n + 1] if n + 1 < len(starts) else end
        yield lines[s], lines[s + 1:e]


def leaves(body):
    rows = []
    for l in body:
        m = re.match(r"^(\s*[+!:| ]*)(\d+) (.*)$", l)
        if m:
            rows.append((len(m.group(1)), int(m.group(2)), m.group(3)))
    stack = []
    for i, (depth, count, frame) in enumerate(rows):
        while stack and stack[-1][0] >= depth:
            stack.pop()
        stack.append((depth, frame))
        nxt = rows[i + 1][0] if i + 1 < len(rows) else -1
        if nxt <= depth:
            yield count, frame, [f for _, f in stack]


def name(frame):
    return re.sub(r"\(.*", "", frame.split("  (in")[0]).replace(
        "static ", "").strip()


def main():
    path = sys.argv[1]
    module = (sys.argv[sys.argv.index("--module") + 1]
              if "--module" in sys.argv else None)
    lines = open(path).read().splitlines()
    mine = (lambda f: f"(in {module})" in f) if module else (
        lambda f: re.search(r"\(in KiwiDesk\w*Tests\)", f))
    blocked = 0
    ws = collections.Counter()
    waits = collections.Counter()
    cpu = collections.Counter()
    for header, body in threads(lines):
        main_thread = "Main Thread" in header
        for count, frame, stack in leaves(body):
            idle = any(k in frame for k in IDLE)
            ours = [name(f) for f in stack if mine(f)]
            if main_thread and "mach_msg" in frame:
                blocked += count
                entry = [f.split("  (in")[0] for f in stack if WS.match(f)]
                if entry:
                    ws[entry[0][:60]] += count
                if ours:
                    waits[" <- ".join(reversed(ours[-3:]))] += count
            if not idle and ours:
                cpu[ours[-1][:70]] += count
        if main_thread:
            total = int(re.search(r"(\d+) Thread", header).group(1))
    print(f"main thread: {total} samples, {blocked} blocked in mach_msg "
          f"({100 * blocked // max(total, 1)} %)")
    print("-- outermost WindowServer entry while blocked")
    for k, c in ws.most_common(8):
        print(f"{c:6}  {k}")
    print("-- test-module frames above those waits")
    for k, c in waits.most_common(12):
        print(f"{c:6}  {k}")
    print("-- busiest test-module frames, all threads, CPU only")
    for k, c in cpu.most_common(12):
        print(f"{c:6}  {k}")


if __name__ == "__main__":
    main()
