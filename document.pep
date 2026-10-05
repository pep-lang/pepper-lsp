# Open documents: their text, kept in step with the client's changes, and
# conversion between protocol positions (UTF-16 columns) and byte offsets.

import "types";

## A document the client has open, as the server last heard of it.
##
## Positions in the protocol count UTF-16 code units from the start of a
## line, and a line ends at `\n`, `\r\n` or `\r`; `offset_at` and
## `position_at` convert them to and from byte offsets into `text`.
export struct TextDocument {
    ## The document's URI.
    var uri: String;
    ## The language, such as `pepper`.
    var language_id: String;
    ## The version of the last change applied.
    var version: int;
    ## The whole text.
    var text: String;
    # The byte offset of each line's first byte.
    var _line_starts: ulong[];

    ## Creates a document.
    ##
    ## @param uri the document's URI
    ## @param text its text
    ## @param version its version
    ## @param language_id its language
    construct(uri: String = "", text: String = "", version: int = 0, language_id: String = "") {
        this.uri = uri;
        this.text = text;
        this.version = version;
        this.language_id = language_id;
        _line_starts = _lines_of(text);
    }

    ## Creates the document `textDocument/didOpen` describes.
    ##
    ## @param item the document opened
    ## @returns the document
    static opened(item: TextDocumentItem): TextDocument {
        return TextDocument(item.uri, item.text, item.version, item.language_id);
    }

    ## Applies the changes of a `textDocument/didChange`, in order, and
    ## takes its version.
    ##
    ## @param params the notification's parameters
    apply_changes(params: DidChangeTextDocumentParams) {
        for (var change in params.content_changes) {
            apply(change);
        }
        version = params.text_document.version;
    }

    ## Applies one change: replaces its range, or the whole text when it
    ## has none.
    ##
    ## @param change the change
    apply(change: TextDocumentContentChangeEvent) {
        if (change.range is Value(range)) {
            ulong start = offset_at(range.start);
            ulong end = offset_at(range.end);
            if (end < start) {
                end = start;
            }
            text = text.substr_bytes(0, start) + change.text + text.substr_bytes(end, text.size - end);
        } else {
            text = change.text;
        }
        _line_starts = _lines_of(text);
    }

    ## The number of lines; a text ending in a line break has an empty last
    ## line.
    var line_count: ulong {
        get {
            return _line_starts.count;
        }
    }

    ## The byte offset of `position`. A line past the last gives the end of
    ## the text, and a column past the end of its line gives the line's end.
    ##
    ## @param position a protocol position
    ## @returns the byte offset into `text`
    offset_at(position: Position): ulong {
        if (position.line < 0) {
            return 0;
        }
        if (position.line as ulong >= _line_starts.count) {
            return text.size;
        }
        ulong offset = _line_starts[position.line as ulong];
        ulong end = _line_end(position.line as ulong);
        long units = position.character as long;
        while (units > 0 and offset < end) {
            var size = _sequence_size(text.byte_at(offset));
            units -= size == 4 ? 2 : 1;
            offset += size;
        }
        return offset > end ? end : offset;
    }

    ## The protocol position of byte offset `offset`; an offset past the
    ## end gives the end of the text.
    ##
    ## @param offset a byte offset into `text`
    ## @returns the position
    position_at(offset: ulong): Position {
        if (offset > text.size) {
            offset = text.size;
        }
        # The last line starting at or before `offset`.
        ulong low = 0;
        ulong high = _line_starts.count;
        while (high - low > 1) {
            ulong middle = (low + high) / 2;
            if (_line_starts[middle] <= offset) {
                low = middle;
            } else {
                high = middle;
            }
        }
        ulong at = _line_starts[low];
        int units = 0;
        while (at < offset) {
            var size = _sequence_size(text.byte_at(at));
            units += size == 4 ? 2 : 1;
            at += size;
        }
        return Position(low as int, units);
    }

    ## The range of bytes `start` up to `end`.
    ##
    ## @param start the first byte offset
    ## @param end the offset past the last
    ## @returns the protocol range
    range_of(start: ulong, end: ulong): Range {
        return Range(position_at(start), position_at(end));
    }

    # The offset where line `line`'s text ends, before its line break.
    _line_end(line: ulong): ulong {
        if (line + 1 >= _line_starts.count) {
            return text.size;
        }
        ulong end = _line_starts[line + 1];
        if (end > 0 and text.byte_at(end - 1) == '\n') {
            end -= 1;
        }
        if (end > 0 and text.byte_at(end - 1) == '\r') {
            end -= 1;
        }
        return end;
    }
}

# The offset of each line's first byte.
_lines_of(text: String): ulong[] {
    var starts = Array<ulong>();
    starts.append(0);
    ulong i = 0;
    while (i < text.size) {
        var c = text.byte_at(i);
        i += 1;
        if (c == '\r' and i < text.size and text.byte_at(i) == '\n') {
            i += 1;
        }
        if (c == '\n' or c == '\r') {
            starts.append(i);
        }
    }
    return starts;
}

# The size of the UTF-8 sequence a lead byte starts; 1 for a byte that
# cannot start one, so a malformed text still moves forward.
_sequence_size(lead: byte): ulong {
    var b = (lead as int) & 0xFF;
    if (b >= 0xF0 and b < 0xF8) {
        return 4;
    }
    if (b >= 0xE0) {
        return b < 0xF0 ? 3 : 1;
    }
    if (b >= 0xC0) {
        return 2;
    }
    return 1;
}
