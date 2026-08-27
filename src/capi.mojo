"""C ABI exports for the Python ctypes wrapper."""

from wyhash import U8Ptr, hash, make_secret


@export("mwh_hash")
def mwh_hash(data_addr: Int, n: Int, seed: UInt64, secret_addr: Int) abi("C") -> UInt64:
    # The public Python wrapper validates both buffers before this raw-pointer ABI.
    # Keep direct C callers from constructing a non-null Mojo pointer from a null
    # address or from turning a negative length into an out-of-bounds read.
    if n < 0 or data_addr == 0 or secret_addr == 0:
        return 0
    return hash(
        U8Ptr(unsafe_from_address=data_addr),
        n,
        seed,
        U8Ptr(unsafe_from_address=secret_addr),
    )


@export("mwh_make_secret")
def mwh_make_secret(seed_in: UInt64, dst_addr: Int) abi("C"):
    if dst_addr == 0:
        return
    make_secret(seed_in, U8Ptr(unsafe_from_address=dst_addr))
