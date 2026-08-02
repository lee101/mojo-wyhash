# mojo-wyhash

`mojo-wyhash` is a native Mojo port of the public API in the PyPI
[`wyhash` 0.1.2](https://pypi.org/project/wyhash/) package. It implements the
final-v3 wyhash algorithm and Wang Yi's deterministic 32-byte secret generator,
then exposes them through a small Python `ctypes` wrapper.

```python
import mojowyhash as wyhash

seed = 42
secret = wyhash.make_secret(seed)
digest = wyhash.hash(b"the same bytes produce the upstream result", seed, secret)
print(digest)
```

## Coverage

The complete public function API of `wyhash` 0.1.2 is covered:

- `hash(data, seed, secret) -> int`
- `make_secret(seed) -> bytes`

`hash` accepts C-contiguous `uint8` buffer-protocol inputs, including `bytes`,
`bytearray`, `memoryview`, and `uint8` NumPy arrays. Its `secret` must be 32
bytes; the check prevents an unsafe native read for malformed input.

The PyPI package exposes no incremental hashing API. This port does not expose
the upstream package's `backends` module or the bundled C header's lower-level
helpers such as `wyrand`, `wyhash64`, and distribution converters.

## Install and run

Pixi provides the pinned Mojo nightly plus the real upstream package used by
the parity suite.

```bash
pixi install
pixi run build
pixi run test
pixi run bench
```

When working from this checkout, Pixi sets `PYTHONPATH=python`, so this is a
complete runnable example:

```bash
pixi run python -c 'import mojowyhash as w; s = w.make_secret(42); print(w.hash(b"the same bytes produce the upstream result", 42, s))'
```

It prints `4015771456737340991`. The wrapper builds `dist/libmojo-wyhash.so`
on first use if it is missing or stale. Set
`MOJO_WYHASH_LIB` to point at an already-built shared library instead.

## Benchmarks

Measured with `pixi run bench` on Linux 6.8.0-136-generic, x86_64, glibc 2.39.
Each number is the best of seven runs in the same Pixi environment against the
upstream `wyhash` 0.1.2 Cython extension.

| kernel | Mojo | upstream wyhash | speedup |
| --- | ---: | ---: | ---: |
| `hash` 64 B | 2.91 us | 0.75 us | 0.26x |
| `hash` 8 MiB | 490.57 us | 651.03 us | 1.33x |
| `make_secret` x1000 | 16.70 ms | 10.35 ms | 0.62x |

The large-message Mojo hash is faster on this measurement, while the Cython/C
reference remains faster for short hashes and secret generation. This project
contains no GPU implementation.

## How it works

The implementation is one Mojo compilation unit. It reads unaligned input as
little-endian 32- and 64-bit words, preserves wyhash's 48-byte three-lane long
message loop, and implements the required 64-by-64-to-128-bit MUM mix using
Mojo's native 128-bit product. `make_secret` uses the reference allowed-byte table,
`wyrand` sequence, odd-word rule, and Hamming-distance check.

Python passes input and secret buffers to the C ABI as integer addresses; Mojo
rebuilds typed pointers inside the export because exported Mojo functions cannot
accept parametric pointer arguments. The hash path does not copy message bytes.
The result is a scalar `uint64`, while secret generation writes into a
caller-owned 32-byte `uint8` array. Empty messages use a retained one-byte
sentinel so Mojo never receives a null pointer.

## Verification

`tests/test_parity.py` compares generated secrets and hashes against the real
PyPI package over all short-message boundaries (0 through 65 bytes), the 16-,
48-, and 96-byte long-message transitions, multi-kilobyte inputs, custom
secrets, buffer types, and unaligned C-ABI buffers.

MIT.
