"""Wyhash final-v3 and its deterministic secret generator."""

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
    var x = value - ((value >> 1) & 0x5555555555555555)
    x = (x & 0x3333333333333333) + ((x >> 2) & 0x3333333333333333)
    x = (x + (x >> 4)) & 0x0F0F0F0F0F0F0F0F
    return Int((x * 0x0101010101010101) >> 56)


def allowed_secret_byte(i: Int) -> UInt8:
    if i == 0: return 15
    elif i == 1: return 23
    elif i == 2: return 27
    elif i == 3: return 29
    elif i == 4: return 30
    elif i == 5: return 39
    elif i == 6: return 43
    elif i == 7: return 45
    elif i == 8: return 46
    elif i == 9: return 51
    elif i == 10: return 53
    elif i == 11: return 54
    elif i == 12: return 57
    elif i == 13: return 58
    elif i == 14: return 60
    elif i == 15: return 71
    elif i == 16: return 75
    elif i == 17: return 77
    elif i == 18: return 78
    elif i == 19: return 83
    elif i == 20: return 85
    elif i == 21: return 86
    elif i == 22: return 89
    elif i == 23: return 90
    elif i == 24: return 92
    elif i == 25: return 99
    elif i == 26: return 101
    elif i == 27: return 102
    elif i == 28: return 105
    elif i == 29: return 106
    elif i == 30: return 108
    elif i == 31: return 113
    elif i == 32: return 114
    elif i == 33: return 116
    elif i == 34: return 120
    elif i == 35: return 135
    elif i == 36: return 139
    elif i == 37: return 141
    elif i == 38: return 142
    elif i == 39: return 147
    elif i == 40: return 149
    elif i == 41: return 150
    elif i == 42: return 153
    elif i == 43: return 154
    elif i == 44: return 156
    elif i == 45: return 163
    elif i == 46: return 165
    elif i == 47: return 166
    elif i == 48: return 169
    elif i == 49: return 170
    elif i == 50: return 172
    elif i == 51: return 177
    elif i == 52: return 178
    elif i == 53: return 180
    elif i == 54: return 184
    elif i == 55: return 195
    elif i == 56: return 197
    elif i == 57: return 198
    elif i == 58: return 201
    elif i == 59: return 202
    elif i == 60: return 204
    elif i == 61: return 209
    elif i == 62: return 210
    elif i == 63: return 212
    elif i == 64: return 216
    elif i == 65: return 225
    elif i == 66: return 226
    elif i == 67: return 228
    elif i == 68: return 232
    else: return 240


def write64(p: U8Ptr, offset: Int, value: UInt64):
    for j in range(8):
        p[offset + j] = UInt8((value >> UInt64(j * 8)) & 0xFF)


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
