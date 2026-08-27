from wyhash import U8Ptr, hash, make_secret


def main() raises:
    var secret = InlineArray[UInt8, 32](fill=0)
    make_secret(42, U8Ptr(unsafe_from_address=Int(secret.unsafe_ptr())))

    var msg = String("the same bytes produce the upstream result")
    var msg_bytes = msg.as_bytes()
    var digest = hash(
        U8Ptr(unsafe_from_address=Int(msg_bytes.unsafe_ptr())),
        len(msg_bytes),
        42,
        U8Ptr(unsafe_from_address=Int(secret.unsafe_ptr())),
    )
    # Matches the published Python example / upstream wyhash for this input.
    if digest != 4015771456737340991:
        raise Error("unexpected digest: " + String(digest))
    print("ok", digest)
