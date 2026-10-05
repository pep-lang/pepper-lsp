# `file:` URIs, which name documents in the protocol, and the paths they
# stand for.

import [Utf8] from text;

## The path a `file:` URI names, with its `%XX` escapes decoded:
## `file:///home/me/a%20b.pep` is `/home/me/a b.pep`, and
## `file:///c%3A/src/a.pep` is `c:/src/a.pep`. Empty for any other scheme.
##
## @param uri the URI
## @returns the path, or Empty when `uri` is not a `file:` URI
export uri_to_path(uri: String): String? {
    if (!uri.starts_with("file://")) {
        return Optional<String>.Empty;
    }
    var rest = uri.substr_bytes(7, uri.size - 7);
    # `file://host/path` names a path on another host; only the local
    # host's (an empty or `localhost` authority) are paths here.
    var slash = rest.find("/");
    if (slash < 0) {
        return Optional<String>.Empty;
    }
    var host = rest.substr_bytes(0, slash as ulong);
    if (!host.is_empty and host != "localhost") {
        return Optional<String>.Empty;
    }
    var path = _decode(rest.substr_bytes(slash as ulong, rest.size - slash as ulong));
    # A Windows drive: `/c:/src` is `c:/src`.
    if (path.size >= 3 and path.byte_at(2) == ':' and _is_letter(path.byte_at(1))) {
        return Optional<String>.Value(path.substr_bytes(1, path.size - 1));
    }
    return Optional<String>.Value(path);
}

## The `file:` URI of an absolute path, escaping what a URI cannot hold:
## `/home/me/a b.pep` is `file:///home/me/a%20b.pep`, and `C:\src\a.pep` is
## `file:///C%3A/src/a.pep`, as VS Code writes them.
##
## @param path an absolute path
## @returns the URI
export path_to_uri(path: String): String {
    var normalized = path.replace("\\", "/");
    var out = Array<u8>();
    for (var c in (normalized.starts_with("/") ? "file://" : "file:///").bytes()) {
        out.append(c);
    }
    for (var i in 0..normalized.size) {
        var c = normalized.byte_at(i);
        if (_is_unreserved(c) or c == '/') {
            out.append(c as u8);
            continue;
        }
        var value = (c as int) & 0xFF;
        out.append('%' as u8);
        out.append(_HEX.byte_at((value >> 4) as ulong) as u8);
        out.append(_HEX.byte_at((value & 15) as ulong) as u8);
    }
    return Utf8.decode_lossy(out);
}

# Whether a URI path may hold `c` unescaped.
_is_unreserved(c: byte): bool {
    return _is_letter(c) or (c >= '0' and c <= '9') or c == '-' or c == '.' or c == '_' or c == '~';
}

_is_letter(c: byte): bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

# The digits of `%XX` escapes.
const _HEX = "0123456789ABCDEF";

# `text` with each `%XX` replaced by the byte it stands for.
_decode(text: String): String {
    if (text.find("%") < 0) {
        return text;
    }
    var bytes = Array<u8>();
    ulong i = 0;
    while (i < text.size) {
        var c = text.byte_at(i);
        if (c == '%' and i + 2 < text.size) {
            var high = _digit(text.byte_at(i + 1));
            var low = _digit(text.byte_at(i + 2));
            if (high >= 0 and low >= 0) {
                bytes.append((high * 16 + low) as u8);
                i += 3;
                continue;
            }
        }
        bytes.append(c as u8);
        i += 1;
    }
    return Utf8.decode_lossy(bytes);
}

# The value of a hex digit, or -1.
_digit(c: byte): int {
    if (c >= '0' and c <= '9') {
        return (c as int) - ('0' as int);
    }
    if (c >= 'a' and c <= 'f') {
        return (c as int) - ('a' as int) + 10;
    }
    if (c >= 'A' and c <= 'F') {
        return (c as int) - ('A' as int) + 10;
    }
    return -1;
}
