"""Mojo implementation of the public API from the ``wyhash`` package."""

from __future__ import annotations

import ctypes

import numpy as np

from ._lib import lib

__all__ = ["hash", "make_secret"]
__version__ = "0.1.0"

_EMPTY_DATA = np.zeros(1, dtype=np.uint8)
_UINT64_MASK = (1 << 64) - 1
_PY_BYTES_AS_STRING = ctypes.pythonapi.PyBytes_AsString
_PY_BYTES_AS_STRING.argtypes = [ctypes.py_object]
_PY_BYTES_AS_STRING.restype = ctypes.c_void_p
_PY_BYTES_FROM_STRING_AND_SIZE = ctypes.pythonapi.PyBytes_FromStringAndSize
_PY_BYTES_FROM_STRING_AND_SIZE.argtypes = [ctypes.c_void_p, ctypes.c_ssize_t]
_PY_BYTES_FROM_STRING_AND_SIZE.restype = ctypes.py_object


def _buffer(value: object, name: str) -> np.ndarray:
    try:
        view = memoryview(value)
    except TypeError as exc:
        raise TypeError(f"{name} must support the buffer protocol") from exc
    if not view.c_contiguous:
        raise ValueError(f"{name} must be C-contiguous")
    if view.format != "B" or view.itemsize != 1:
        raise TypeError(f"{name} must be a uint8 buffer")
    return np.frombuffer(view.cast("B"), dtype=np.uint8)


def _buffer_address(value: object, name: str) -> tuple[int, int]:
    if isinstance(value, bytes):
        return len(value), _PY_BYTES_AS_STRING(value) if value else _EMPTY_DATA.ctypes.data
    array = _buffer(value, name)
    return array.size, array.ctypes.data if array.size else _EMPTY_DATA.ctypes.data


def _uint64(value: int | np.integer, name: str) -> int:
    if not isinstance(value, (int, np.integer)):
        raise TypeError(f"{name} must be an integer")
    value = int(value)
    if not 0 <= value <= _UINT64_MASK:
        raise OverflowError(f"{name} must fit in an unsigned 64-bit integer")
    return value


def hash(data: object, seed: int, secret: object) -> int:
    """Return the wyhash final-v3 64-bit hash for ``data``.

    This has the same ``(data, seed, secret)`` signature as ``wyhash.hash``.
    ``secret`` must be the 32-byte value returned by :func:`make_secret`.
    """
    seed = _uint64(seed, "seed")
    if isinstance(data, bytes) and isinstance(secret, bytes):
        if len(secret) != 32:
            raise ValueError("secret must contain exactly 32 bytes")
        data_addr = _PY_BYTES_AS_STRING(data) if data else _EMPTY_DATA.ctypes.data
        return int(
            lib().mwh_hash(
                data_addr, len(data), seed, _PY_BYTES_AS_STRING(secret)
            )
        )

    data_size, data_addr = _buffer_address(data, "data")
    secret_size, secret_addr = _buffer_address(secret, "secret")
    if secret_size != 32:
        raise ValueError("secret must contain exactly 32 bytes")
    return int(lib().mwh_hash(data_addr, data_size, seed, secret_addr))


def make_secret(seed: int | float) -> bytes:
    """Make the deterministic 32-byte wyhash secret for ``seed``."""
    secret = _PY_BYTES_FROM_STRING_AND_SIZE(None, 32)
    lib().mwh_make_secret(
        _uint64(seed, "seed"), _PY_BYTES_AS_STRING(secret)
    )
    return secret
