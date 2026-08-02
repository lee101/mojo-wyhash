"""Benchmark Mojo wyhash against the upstream Cython extension."""

from __future__ import annotations

import os
import platform
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "python"))

import mojowyhash as mojo
import wyhash as upstream


def best_time(fn, repeat: int = 7) -> float:
    best = float("inf")
    for _ in range(repeat):
        start = time.perf_counter()
        fn()
        best = min(best, time.perf_counter() - start)
    return best


def main() -> None:
    seed = 0x123456789ABCDEF0
    secret = upstream.make_secret(seed)
    cases = [
        ("hash 64 B", bytes(range(64))),
        ("hash 8 MiB", (bytes(range(256)) * 32_768)),
    ]
    print(f"Machine: {platform.platform()} ({platform.machine()})")
    print("| kernel | Mojo | upstream wyhash | speedup |")
    print("| --- | ---: | ---: | ---: |")
    for name, data in cases:
        mojo.hash(data, seed, secret)
        upstream.hash(data, seed, secret)
        ours = best_time(lambda: mojo.hash(data, seed, secret))
        theirs = best_time(lambda: upstream.hash(data, seed, secret))
        print(f"| `{name}` | {ours * 1e6:.2f} us | {theirs * 1e6:.2f} us | {theirs / ours:.2f}x |")

    mojo.make_secret(seed)
    upstream.make_secret(seed)
    ours = best_time(lambda: [mojo.make_secret(i) for i in range(1_000)])
    theirs = best_time(lambda: [upstream.make_secret(i) for i in range(1_000)])
    print(f"| `make_secret` x1000 | {ours * 1e3:.2f} ms | {theirs * 1e3:.2f} ms | {theirs / ours:.2f}x |")


if __name__ == "__main__":
    main()
