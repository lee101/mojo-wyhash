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

## Mojo package (pixi-build)

`src/wyhash/` is a Mojo package built by `pixi-build-mojo` into
`$PREFIX/lib/mojo/wyhash.mojoc`. That build lives in its own environment, so
`pixi install`, `pixi run build` and `pixi run test` never wait on a source
build of the package itself. To exercise it:

```bash
pixi run package-pixi-build
```

Publish with:

```bash
pixi publish --target-channel ./mojo-channel
# or a prefix.dev / R2 channel
```

Consumers can add channel `https://twohelixesstatic.twohelixes.com/mojo-channel`
(or a prefix.dev channel) and `pixi add mojo-wyhash`. The Python ctypes path is
unchanged and still uses `src/capi.mojo` → `dist/libmojo-wyhash.so`.

## Benchmarks

Measured with `pixi run bench` on Linux 6.8.0-136-generic, x86_64, glibc 2.39.
Each number is the best of seven runs in the same Pixi environment against the
upstream `wyhash` 0.1.2 Cython extension.

| kernel | Mojo | upstream wyhash | speedup |
| --- | ---: | ---: | ---: |
| `hash 64 B` | 2.60 us | 0.76 us | 0.29x |
| `hash 8 MiB` | 455.90 us | 647.46 us | 1.42x |
| `make_secret` x1000 | 8.08 ms | 9.53 ms | 1.18x |

The large-message Mojo hash and secret generation are faster on this
measurement. Short hashes remain dominated by Python validation and `ctypes`
call overhead. Secret generation uses a single constant lookup table, hardware
popcount, and unaligned 8-byte SIMD stores; its Python path writes directly into
one freshly allocated `bytes` object without an intermediate NumPy allocation
or copy.

Hashing is dependency-chained within each call, and the public API has no batch
operation whose items could be parallelized independently, so thread-launch
overhead cannot be amortized. The hash also performs well below two arithmetic
operations per byte moved. It is therefore unsuitable for GPU offload, and this
project intentionally has no parallel or GPU path.

## How it works

The Mojo API lives in `src/wyhash/`. `src/capi.mojo` re-exports the C ABI used by
the Python wrapper. It reads unaligned input as little-endian 32- and 64-bit
words, preserves wyhash's 48-byte three-lane long message loop, and implements
the required 64-by-64-to-128-bit MUM mix using Mojo's native 128-bit product.
`make_secret` uses the reference allowed-byte table, `wyrand` sequence, odd-word
rule, and Hamming-distance check.

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
