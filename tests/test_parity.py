"""Parity with the real ``wyhash`` 0.1.2 Python package."""

from __future__ import annotations

import ctypes

import numpy as np
import pytest
import wyhash as upstream

import mojowyhash as mojo
from mojowyhash import _buffer_address
from mojowyhash._lib import lib


SEEDS = (0, 1, 42, (1 << 64) - 1)
LENGTHS = tuple(range(66)) + (95, 96, 97, 255, 256, 257, 4096)
DATA = bytes(range(256)) * 17


@pytest.mark.parametrize("seed", SEEDS)
def test_make_secret_matches_upstream(seed):
    assert mojo.make_secret(seed) == upstream.make_secret(seed)


@pytest.mark.parametrize("seed", SEEDS)
@pytest.mark.parametrize("length", LENGTHS)
def test_hash_matches_upstream_across_all_length_branches(seed, length):
    secret = upstream.make_secret(seed)
    data = (DATA * ((length + len(DATA) - 1) // len(DATA)))[:length]
    assert mojo.hash(data, seed, secret) == upstream.hash(data, seed, secret)


@pytest.mark.parametrize("seed", (0, 7, 0x123456789ABCDEF0))
@pytest.mark.parametrize("length", (0, 1, 3, 4, 16, 17, 48, 49, 127, 2049))
def test_hash_matches_upstream_with_a_caller_supplied_secret(seed, length):
    secret = bytes(range(32))
    data = (b"wyhash final-v3\x00" * 200)[:length]
    assert mojo.hash(data, seed, secret) == upstream.hash(data, seed, secret)


@pytest.mark.parametrize("value", [b"buffer input", bytearray(b"buffer input"), memoryview(b"buffer input")])
def test_bytes_like_inputs_match_upstream(value):
    secret = mojo.make_secret(123)
    assert mojo.hash(value, 123, secret) == upstream.hash(value, 123, secret)


def test_numpy_uint8_buffer_matches_upstream():
    data = np.arange(251, dtype=np.uint8)
    secret = np.frombuffer(mojo.make_secret(7), dtype=np.uint8)
    assert mojo.hash(data, 7, secret) == upstream.hash(data, 7, secret)


@pytest.mark.parametrize("value", [np.arange(4, dtype=np.int8), np.arange(4, dtype=np.uint16)])
def test_non_uint8_numpy_buffers_are_rejected(value):
    with pytest.raises(TypeError, match="uint8 buffer"):
        mojo.hash(value, 0, mojo.make_secret(0))


@pytest.mark.parametrize("value", [1.0, np.float64(1.0), 1.5])
def test_float_seeds_are_rejected_without_silent_narrowing(value):
    with pytest.raises(TypeError, match="must be an integer"):
        mojo.make_secret(value)


def test_bytes_fast_path_exposes_the_original_buffer():
    data = b"zero-copy bytes"
    size, address = _buffer_address(data, "data")
    assert size == len(data)
    assert ctypes.string_at(address, size) == data


def test_c_abi_handles_unaligned_data_and_secret_buffers():
    data = (ctypes.c_ubyte * 100)()
    secret = (ctypes.c_ubyte * 33)()
    message = bytes(range(97))
    generated = upstream.make_secret(91)
    for i, byte in enumerate(message):
        data[i + 1] = byte
    for i, byte in enumerate(generated):
        secret[i + 1] = byte
    actual = lib().mwh_hash(
        ctypes.addressof(data) + 1,
        len(message),
        91,
        ctypes.addressof(secret) + 1,
    )
    assert actual == upstream.hash(message, 91, generated)


def test_c_abi_make_secret_handles_unaligned_output():
    destination = (ctypes.c_ubyte * 33)()
    lib().mwh_make_secret(91, ctypes.addressof(destination) + 1)
    assert bytes(destination[1:]) == upstream.make_secret(91)


def test_invalid_secret_is_rejected_without_native_out_of_bounds_reads():
    with pytest.raises(ValueError, match="exactly 32 bytes"):
        mojo.hash(b"x", 0, b"too short")


def test_c_abi_rejects_null_addresses_and_negative_lengths():
    native = lib()
    assert native.mwh_hash(0, 0, 0, 0) == 0
    assert native.mwh_hash(0, -1, 0, 0) == 0
    native.mwh_make_secret(0, 0)
