# The base protocol's framing: each message is a header block
# (`Content-Length: <bytes>`, optionally `Content-Type`, each line ending in
# `\r\n`), an empty line, then that many bytes of UTF-8 JSON.

import io;
import json;
import [JsonValue] from json;
import [Utf8] from text;

## Reads framed messages from a stream, one at a time.
export struct MessageReader {
    var _input: io.Reader;
    # Bytes read from the stream and not yet returned.
    var _buffer: u8[];
    # Where the unread bytes of `_buffer` start.
    var _start: ulong;
    # Whether the stream has ended and every byte read was returned.
    var _at_end: bool;

    ## Creates a reader over `input`.
    ##
    ## @param input the stream the client writes to, usually standard input
    construct(input: io.Reader) {
        _input = input;
        _buffer = Array<u8>();
        _start = 0;
        _at_end = false;
    }

    ## Reads the next message.
    ##
    ## @returns the message's JSON, Empty at the end of the stream, or an
    ##     error naming what is wrong with the framing or the JSON
    read(): Result<JsonValue?, String> {
        long length = -1;
        bool started = false;
        while (true) {
            var line = _line();
            if (line.is_err()) {
                return Result<JsonValue?, String>.err(line.error());
            }
            if (line.value().is_empty()) {
                if (!started and _at_end) {
                    return Result<JsonValue?, String>.ok(Optional<JsonValue>.Empty);
                }
                return Result<JsonValue?, String>.err("unexpected end of input in a header");
            }
            var text = line.value().value();
            started = true;
            if (text.size == 0) {
                break;
            }
            var colon = text.find(":");
            if (colon < 0) {
                return Result<JsonValue?, String>.err($"malformed header '{text}'");
            }
            var name = text.substr_bytes(0, colon as ulong).trim().lower();
            if (name != "content-length") {
                continue;
            }
            var value = text.substr_bytes(colon as ulong + 1, text.size - colon as ulong - 1).trim();
            var parsed = long.parse(value);
            if (parsed.is_empty() or parsed.value() < 0) {
                return Result<JsonValue?, String>.err($"bad Content-Length '{value}'");
            }
            length = parsed.value();
        }
        if (length < 0) {
            return Result<JsonValue?, String>.err("a message without a Content-Length header");
        }
        var filled = _fill(length as ulong);
        if (filled.is_err()) {
            return Result<JsonValue?, String>.err(filled.error());
        }
        if (_buffer.count - _start < length as ulong) {
            return Result<JsonValue?, String>.err("unexpected end of input in a message body");
        }
        var body = Utf8.decode_lossy(_bytes(_start, _start + length as ulong));
        _start += length as ulong;
        _compact();
        var value = json.parse(body);
        if (value.is_err()) {
            return Result<JsonValue?, String>.err($"invalid JSON: {value.error().message}");
        }
        return Result<JsonValue?, String>.ok(Optional<JsonValue>.Value(value.value()));
    }

    # The next header line without its `\r\n`; Empty at the end of the
    # stream.
    _line(): Result<String?, String> {
        while (true) {
            for (var i in _start.._buffer.count) {
                if (_buffer[i] != '\n' as u8) {
                    continue;
                }
                ulong end = i;
                if (end > _start and _buffer[end - 1] == '\r' as u8) {
                    end -= 1;
                }
                var line = Utf8.decode_lossy(_bytes(_start, end));
                _start = i + 1;
                return Result<String?, String>.ok(Optional<String>.Value(line));
            }
            var read = _read_more();
            if (read.is_err()) {
                return Result<String?, String>.err(read.error());
            }
            if (read.value() == 0) {
                _at_end = _start == _buffer.count;
                return Result<String?, String>.ok(Optional<String>.Empty);
            }
        }
        return Result<String?, String>.ok(Optional<String>.Empty);
    }

    # Reads until at least `size` unread bytes are buffered or the stream
    # ends.
    _fill(size: ulong): Result<void, String> {
        while (_buffer.count - _start < size) {
            var read = _read_more();
            if (read.is_err()) {
                return Result<void, String>.err(read.error());
            }
            if (read.value() == 0) {
                break;
            }
        }
        return Result<void, String>.ok();
    }

    _read_more(): Result<ulong, String> {
        var read = _input.read(_buffer, 65536);
        if (read.is_err()) {
            return Result<ulong, String>.err($"read failed: {read.error().message}");
        }
        return Result<ulong, String>.ok(read.value());
    }

    # A new array of the buffered bytes from `start` up to `end`.
    _bytes(start: ulong, end: ulong): u8[] {
        var out = Array<u8>();
        out.reserve(end - start);
        for (var i in start..end) {
            out.append(_buffer[i]);
        }
        return out;
    }

    # Drops the bytes already returned once they are most of the buffer.
    _compact() {
        if (_start < 65536 or _start * 2 < _buffer.count) {
            return;
        }
        _buffer = _bytes(_start, _buffer.count);
        _start = 0;
    }
}

## Writes `message` to `output` with its header.
##
## @param output the stream the client reads, usually standard output
## @param message the message
## @returns an error when the stream fails
export write_message(output: io.Writer, message: JsonValue): io.IoResult<void> {
    return write_text(output, message.to_string());
}

## Writes a message already encoded as JSON text to `output` with its
## header.
##
## @param output the stream the client reads
## @param body the message's JSON text
## @returns an error when the stream fails
export write_text(output: io.Writer, body: String): io.IoResult<void> {
    var framed = $"Content-Length: {body.size}\r\n\r\n{body}";
    return output.write_all(framed.bytes());
}
