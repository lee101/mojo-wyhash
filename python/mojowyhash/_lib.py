"""Build and load the Mojo wyhash shared library."""

from __future__ import annotations

import ctypes
import os
import shutil
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LIB = os.environ.get("MOJO_WYHASH_LIB") or os.path.join(ROOT, "dist", "libmojo-wyhash.so")
I = ctypes.c_int64
U64 = ctypes.c_uint64


class BuildError(RuntimeError):
    pass


def build(force: bool = False) -> str:
    """Build the shared library if it is missing or stale."""
    source = os.path.join(ROOT, "src", "wyhash.mojo")
    if not force and os.path.exists(LIB) and os.path.getmtime(LIB) >= os.path.getmtime(source):
        return LIB
    if os.environ.get("MOJO_WYHASH_LIB"):
        raise BuildError(f"MOJO_WYHASH_LIB does not point to a usable library: {LIB}")
    if not shutil.which("mojo"):
        raise BuildError("mojo is not on PATH; run through `pixi run` or set MOJO_WYHASH_LIB")
    proc = subprocess.run(
        ["bash", os.path.join(ROOT, "build", "build.sh")],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=1800,
    )
    if proc.returncode or not os.path.exists(LIB):
        raise BuildError((proc.stderr or proc.stdout).strip()[:4000])
    return LIB


_loaded: ctypes.CDLL | None = None


def lib() -> ctypes.CDLL:
    global _loaded
    if _loaded is None:
        _loaded = ctypes.CDLL(build())
        _loaded.mwh_hash.argtypes = [I, I, U64, I]
        _loaded.mwh_hash.restype = U64
        _loaded.mwh_make_secret.argtypes = [U64, I]
        _loaded.mwh_make_secret.restype = None
    return _loaded
