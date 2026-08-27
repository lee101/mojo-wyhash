"""Wyhash final-v3 and its deterministic secret generator."""

from std.bit import pop_count
from std.builtin.globals import global_constant
from std.memory import bitcast

comptime U8Ptr = UnsafePointer[UInt8, AnyOrigin[mut=True]]
comptime MASK32: UInt64 = 0xFFFFFFFF
comptime WYP0: UInt64 = 0xA0761D6478BD642F
comptime WYP1: UInt64 = 0xE7037ED1A0B428DB


def read32(p: U8Ptr, offset: Int) -> UInt64:
    return UInt64((p + offset).bitcast[UInt32]().load[alignment=1]())


def read64(p: U8Ptr, offset: Int) -> UInt64:
    return (p + offset).bitcast[UInt64]().load[alignment=1]()


def wymix(a: UInt64, b: UInt64) -> UInt64:
    var product = UInt128(a) * UInt128(b)
    return UInt64(product) ^ UInt64(product >> 64)


def wyhash_final3(p: U8Ptr, n: Int, seed_in: UInt64, secret: U8Ptr) -> UInt64:
    var seed = seed_in ^ read64(secret, 0)
    var a: UInt64
    var b: UInt64
    if n <= 16:
        if n >= 4:
            a = (read32(p, 0) << 32) | read32(p, (n >> 3) << 2)
            b = (read32(p, n - 4) << 32) | read32(p, n - 4 - ((n >> 3) << 2))
        elif n > 0:
            a = (UInt64(p[0]) << 16) | (UInt64(p[n >> 1]) << 8) | UInt64(p[n - 1])
            b = 0
        else:
            a = 0
            b = 0
    else:
        var i = n
        var offset = 0
        if i > 48:
            var see1 = seed
            var see2 = seed
            while i > 48:
                seed = wymix(read64(p, offset) ^ read64(secret, 8), read64(p, offset + 8) ^ seed)
                see1 = wymix(read64(p, offset + 16) ^ read64(secret, 16), read64(p, offset + 24) ^ see1)
                see2 = wymix(read64(p, offset + 32) ^ read64(secret, 24), read64(p, offset + 40) ^ see2)
                offset += 48
                i -= 48
            seed ^= see1 ^ see2
        while i > 16:
            seed = wymix(read64(p, offset) ^ read64(secret, 8), read64(p, offset + 8) ^ seed)
            i -= 16
            offset += 16
        a = read64(p, offset + i - 16)
        b = read64(p, offset + i - 8)
    return wymix(read64(secret, 8) ^ UInt64(n), wymix(a ^ read64(secret, 8), b ^ seed))


def wyrand(seed: UInt64) -> UInt64:
    var state = seed + WYP0
    return wymix(state, state ^ WYP1)


def popcount64(value: UInt64) -> Int:
    return Int(pop_count(value))


def allowed_secret_byte(i: Int) -> UInt8:
    comptime table: Array[UInt8, 70] = [
        15, 23, 27, 29, 30, 39, 43, 45, 46, 51,
        53, 54, 57, 58, 60, 71, 75, 77, 78, 83,
        85, 86, 89, 90, 92, 99, 101, 102, 105, 106,
        108, 113, 114, 116, 120, 135, 139, 141, 142, 147,
        149, 150, 153, 154, 156, 163, 165, 166, 169, 170,
        172, 177, 178, 180, 184, 195, 197, 198, 201, 202,
        204, 209, 210, 212, 216, 225, 226, 228, 232, 240,
    ]
    ref static_table = global_constant[table]()
    return static_table[i]


def write64(p: U8Ptr, offset: Int, value: UInt64):
    p.store[alignment=1](
        offset, bitcast[DType.uint8, 8](SIMD[DType.uint64, 1](value))
    )


def secret_candidate(seed: UInt64) -> UInt64:
    var state = seed + WYP0
    var candidate = UInt64(allowed_secret_byte(Int(wymix(state, state ^ WYP1) % 70)))
    state += WYP0
    candidate |= UInt64(allowed_secret_byte(Int(wymix(state, state ^ WYP1) % 70))) << 8
    state += WYP0
    candidate |= UInt64(allowed_secret_byte(Int(wymix(state, state ^ WYP1) % 70))) << 16
    state += WYP0
    candidate |= UInt64(allowed_secret_byte(Int(wymix(state, state ^ WYP1) % 70))) << 24
    state += WYP0
    candidate |= UInt64(allowed_secret_byte(Int(wymix(state, state ^ WYP1) % 70))) << 32
    state += WYP0
    candidate |= UInt64(allowed_secret_byte(Int(wymix(state, state ^ WYP1) % 70))) << 40
    state += WYP0
    candidate |= UInt64(allowed_secret_byte(Int(wymix(state, state ^ WYP1) % 70))) << 48
    state += WYP0
    candidate |= UInt64(allowed_secret_byte(Int(wymix(state, state ^ WYP1) % 70))) << 56
    return candidate


def make_secret(seed_in: UInt64, dst: U8Ptr):
    """Write the deterministic 32-byte wyhash secret for ``seed_in`` into ``dst``."""
    var seed = seed_in
    var word0: UInt64 = 0
    var word1: UInt64 = 0
    var word2: UInt64 = 0
    for i in range(4):
        var accepted = False
        var chosen: UInt64 = 0
        while not accepted:
            var candidate = secret_candidate(seed)
            seed += WYP0 * 8
            if (candidate & 1) != 0:
                accepted = True
                if i >= 1 and popcount64(word0 ^ candidate) != 32:
                    accepted = False
                if i >= 2 and popcount64(word1 ^ candidate) != 32:
                    accepted = False
                if i >= 3 and popcount64(word2 ^ candidate) != 32:
                    accepted = False
            if accepted:
                chosen = candidate
                if i == 0:
                    word0 = candidate
                elif i == 1:
                    word1 = candidate
                elif i == 2:
                    word2 = candidate
        write64(dst, i * 8, chosen)


def hash(data: U8Ptr, n: Int, seed: UInt64, secret: U8Ptr) -> UInt64:
    """Return the wyhash final-v3 digest for ``n`` bytes at ``data``."""
    return wyhash_final3(data, n, seed, secret)
