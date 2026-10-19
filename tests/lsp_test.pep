# The framework's tests: framing, positions, and a whole session run
# through `serve` in memory.

import async;
import [Channel] from async;
import io;
import json;
import [JsonValue] from json;
import lsp;
import [ResponseError] from lsp;
import [Utf8] from text;

# ── Helpers ──────────────────────────────────────────────────────────────

frame(message: String): String {
    return $"Content-Length: {message.size}\r\n\r\n{message}";
}

# The messages a server queued, in order.
messages_in(outgoing: Channel<String>): Array<JsonValue> {
    var out = Array<JsonValue>();
    while (true) {
        var message = outgoing.try_receive();
        if (message.is_err()) {
            break;
        }
        out.append(json.parse(message.value()).value());
    }
    return out;
}

# A server that hovers with the word under the cursor and reports each
# line starting with "!" as an error.
struct Echo {
    var client: lsp.Client;
    var documents: HashMap<String, lsp.TextDocument>;
    var shut_down: bool;

    construct(client: lsp.Client) {
        this.client = client;
        this.documents = HashMap<String, lsp.TextDocument>();
        this.shut_down = false;
    }

    check(document: lsp.TextDocument) {
        var diagnostics = Array<lsp.Diagnostic>();
        for (var line in 0..document.line_count) {
            var start = document.offset_at(lsp.Position(line as int, 0));
            if (start < document.text.size and document.text.byte_at(start) == '!') {
                diagnostics.append(lsp.Diagnostic(document.range_of(start, start + 1), "bang"));
            }
        }
        client.publish_diagnostics(document.uri, diagnostics);
    }
}

extend Echo with lsp.LanguageServer {
    initialize(params: lsp.InitializeParams): Result<lsp.InitializeResult, ResponseError> {
        var result = lsp.InitializeResult();
        result.capabilities.text_document_sync = Optional<lsp.TextDocumentSyncOptions>.Value(
            lsp.TextDocumentSyncOptions(lsp.SYNC_INCREMENTAL)
        );
        result.capabilities.hover_provider = Optional<bool>.Value(true);
        return Result<lsp.InitializeResult, ResponseError>.ok(result);
    }

    shutdown(): Result<void, ResponseError> {
        shut_down = true;
        return Result<void, ResponseError>.ok();
    }

    did_open(params: lsp.DidOpenTextDocumentParams) {
        var document = lsp.TextDocument.opened(params.text_document);
        documents[document.uri] = document;
        check(document);
    }

    did_change(params: lsp.DidChangeTextDocumentParams) {
        var document = documents.try_get(params.text_document.uri);
        if (document is Value(open)) {
            open.apply_changes(params);
            check(open);
        }
    }

    hover(params: lsp.TextDocumentPositionParams): Result<lsp.Hover?, ResponseError> {
        var document = documents.try_get(params.text_document.uri);
        if (document.is_empty()) {
            return Result<lsp.Hover?, ResponseError>.ok(Optional<lsp.Hover>.Empty);
        }
        var text = document.value().text;
        var at = document.value().offset_at(params.position);
        var start = at;
        while (start > 0 and text.byte_at(start - 1) != ' ' and text.byte_at(start - 1) != '\n') {
            start -= 1;
        }
        var end = at;
        while (end < text.size and text.byte_at(end) != ' ' and text.byte_at(end) != '\n') {
            end += 1;
        }
        var hover = lsp.Hover(lsp.MarkupContent(lsp.PLAIN_TEXT, text.substr_bytes(start, end - start)));
        return Result<lsp.Hover?, ResponseError>.ok(Optional<lsp.Hover>.Value(hover));
    }

    request(method: String, params: JsonValue): Result<JsonValue, ResponseError> {
        if (method == "echo/params") {
            return Result<JsonValue, ResponseError>.ok(params);
        }
        return Result<JsonValue, ResponseError>.err(ResponseError.method_not_found(method));
    }
}

# Runs `messages` (JSON texts), then the end of the input, through an Echo
# server.
run_session(messages: Array<String>, outgoing: Channel<String>): int {
    var inbound = Channel<lsp.Inbound>();
    for (var message in messages) {
        inbound.send(copy(lsp.Inbound.Message(json.parse(message).value())));
    }
    inbound.send(lsp.Inbound.End(""));
    return lsp.serve<Echo>((client) => Echo(client), inbound, outgoing);
}

const INITIALIZE = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"capabilities\":{}}}";
const SHUTDOWN = "{\"jsonrpc\":\"2.0\",\"id\":99,\"method\":\"shutdown\"}";
const EXIT = "{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}";

# ── Framing ──────────────────────────────────────────────────────────────

[Test]
reads_framed_messages_in_order() {
    var input = frame("{\"a\":1}")
        + "content-length: 7\r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n{\"b\":2}";
    var reader = lsp.MessageReader(io.ByteReader(input.bytes()));
    expect_equal(reader.read().value().value()["a"].as_int().value(), 1);
    expect_equal(reader.read().value().value()["b"].as_int().value(), 2);
    expect_true(reader.read().value().is_empty());
}

[Test]
counts_the_length_in_bytes() {
    var body = "{\"s\":\"é😀\"}";
    var reader = lsp.MessageReader(io.ByteReader((frame(body) + frame("{}")).bytes()));
    expect_equal(reader.read().value().value()["s"].as_string().value(), "é😀");
    expect_true(reader.read().value().is_value());
}

[Test]
reports_broken_framing() {
    var missing = lsp.MessageReader(io.ByteReader("Content-Type: x\r\n\r\n{}".bytes()));
    expect_true(missing.read().is_err());
    var short = lsp.MessageReader(io.ByteReader("Content-Length: 10\r\n\r\n{}".bytes()));
    expect_true(short.read().is_err());
    var bad = lsp.MessageReader(io.ByteReader("Content-Length: x\r\n\r\n{}".bytes()));
    expect_true(bad.read().is_err());
}

[Test]
writes_a_header_and_the_body() {
    var output = io.ByteWriter();
    var message = JsonValue.object();
    message["s"] = JsonValue.String("é");
    lsp.write_message(output, message);
    expect_equal(Utf8.decode_lossy(output.bytes), "Content-Length: 10\r\n\r\n{\"s\":\"é\"}");
}

# ── Documents ────────────────────────────────────────────────────────────

[Test]
converts_utf16_columns_to_byte_offsets() {
    # "é" is 2 bytes and 1 unit; "😀" is 4 bytes and 2 units.
    var document = lsp.TextDocument("file:///a", "aé😀b\r\nxy\rz\n");
    expect_equal(document.line_count, 4 as ulong);
    expect_equal(document.offset_at(lsp.Position(0, 2)), 3 as ulong);
    expect_equal(document.offset_at(lsp.Position(0, 4)), 7 as ulong);
    expect_equal(document.offset_at(lsp.Position(0, 99)), 8 as ulong);
    expect_equal(document.offset_at(lsp.Position(1, 1)), 11 as ulong);
    expect_equal(document.offset_at(lsp.Position(2, 0)), 13 as ulong);
    expect_equal(document.offset_at(lsp.Position(9, 0)), document.text.size);
    var position = document.position_at(7);
    expect_equal(position.line, 0);
    expect_equal(position.character, 4);
    position = document.position_at(14);
    expect_equal(position.line, 2);
    expect_equal(position.character, 1);
}

[Test]
applies_incremental_and_full_changes() {
    var document = lsp.TextDocument("file:///a", "one\ntwo\n", 1);
    var params = json.from_json<lsp.DidChangeTextDocumentParams>(
        json.parse(
            "{\"textDocument\":{\"uri\":\"file:///a\",\"version\":2},\"contentChanges\":["
                + "{\"range\":{\"start\":{\"line\":1,\"character\":0},\"end\":{\"line\":1,\"character\":3}},\"text\":\"2\"},"
                + "{\"range\":{\"start\":{\"line\":0,\"character\":3},\"end\":{\"line\":0,\"character\":3}},\"text\":\"!\"}]}"
        ).value()
    ).value();
    document.apply_changes(params);
    expect_equal(document.text, "one!\n2\n");
    expect_equal(document.version, 2);
    var whole = lsp.TextDocumentContentChangeEvent();
    whole.text = "new";
    document.apply(whole);
    expect_equal(document.text, "new");
    expect_equal(document.line_count, 1 as ulong);
}

# ── Sessions ─────────────────────────────────────────────────────────────

[Test]
runs_a_session_from_initialize_to_exit() {
    var output = Channel<String>();
    var code = run_session(
        [
            "{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"textDocument/hover\",\"params\":{}}",
            INITIALIZE,
            "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}",
            "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":"
                + "{\"uri\":\"file:///a\",\"languageId\":\"x\",\"version\":1,\"text\":\"hello world\\n!bang\"}}}",
            "{\"jsonrpc\":\"2.0\",\"id\":\"h\",\"method\":\"textDocument/hover\",\"params\":"
                + "{\"textDocument\":{\"uri\":\"file:///a\"},\"position\":{\"line\":0,\"character\":8}}}",
            SHUTDOWN,
            EXIT
        ],
        output
    );
    expect_equal(code, 0);
    var messages = messages_in(output);
    expect_equal(messages.count, 5 as ulong);
    expect_equal(messages[0]["error"]["code"].as_int().value(), lsp.SERVER_NOT_INITIALIZED as long);
    var capabilities = messages[1]["result"]["capabilities"];
    expect_equal(
        capabilities.to_string(), "{\"textDocumentSync\":{\"openClose\":true,\"change\":2},\"hoverProvider\":true}"
    );
    expect_equal(messages[2]["method"].as_string().value(), "textDocument/publishDiagnostics");
    var diagnostic = messages[2]["params"]["diagnostics"][0];
    expect_equal(diagnostic["message"].as_string().value(), "bang");
    expect_equal(diagnostic["range"]["start"]["line"].as_int().value(), 1);
    expect_equal(messages[3]["id"].as_string().value(), "h");
    expect_equal(messages[3]["result"]["contents"]["value"].as_string().value(), "world");
    expect_equal(messages[4]["id"].as_int().value(), 99);
    expect_true(messages[4]["result"].is_null());
}

[Test]
answers_unknown_and_invalid_requests() {
    var output = Channel<String>();
    run_session(
        [
            INITIALIZE,
            "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/definition\",\"params\":"
                + "{\"textDocument\":{\"uri\":\"file:///a\"},\"position\":{\"line\":0,\"character\":0}}}",
            "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/hover\",\"params\":{\"position\":{}}}",
            "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"echo/params\",\"params\":[1,2]}",
            "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"other/thing\"}",
            EXIT
        ],
        output
    );
    var messages = messages_in(output);
    expect_equal(messages[1]["error"]["code"].as_int().value(), lsp.METHOD_NOT_FOUND as long);
    expect_equal(messages[2]["error"]["code"].as_int().value(), lsp.INVALID_PARAMS as long);
    expect_equal(messages[3]["result"].to_string(), "[1,2]");
    expect_equal(messages[4]["error"]["code"].as_int().value(), lsp.METHOD_NOT_FOUND as long);
}

[Test]
exits_with_1_without_shutdown_and_refuses_requests_after_it() {
    var output = Channel<String>();
    expect_equal(run_session([INITIALIZE, EXIT], output), 1);
    output = Channel<String>();
    run_session([INITIALIZE, SHUTDOWN, "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"shutdown\"}", EXIT], output);
    var messages = messages_in(output);
    expect_equal(messages[2]["error"]["code"].as_int().value(), lsp.INVALID_REQUEST as long);
    output = Channel<String>();
    expect_equal(run_session([INITIALIZE], output), 1);
}

[Test]
leaves_out_null_members() {
    var item = lsp.CompletionItem("name", lsp.COMPLETION_FUNCTION);
    expect_equal(lsp.to_protocol_json(item).to_string(), "{\"label\":\"name\",\"kind\":3}");
    var edit = lsp.WorkspaceEdit();
    edit.add("file:///a", lsp.TextEdit(lsp.Range(), "x"));
    edit.add("file:///a", lsp.TextEdit(lsp.Range(), "y"));
    expect_equal(edit.changes["file:///a"].count, 2 as ulong);
}

# A server that counts a document's words on another thread and publishes
# the count from its own thread once woken.
struct Counter {
    var client: lsp.Client;
    const results: Channel<String>;
    var workers: Array<async.Thread>;

    construct(client: lsp.Client) {
        this.client = client;
        this.results = Channel<String>();
        this.workers = Array<async.Thread>();
    }
}

extend Counter with lsp.LanguageServer {
    initialize(params: lsp.InitializeParams): Result<lsp.InitializeResult, ResponseError> {
        return Result<lsp.InitializeResult, ResponseError>.ok(lsp.InitializeResult());
    }

    did_open(params: lsp.DidOpenTextDocumentParams) {
        var texts = Channel<String>();
        texts.send(copy(params.text_document.text));
        var results = this.results;
        var client = this.client;
        workers.append(async.Thread.spawn(() => {
            var text = texts.receive().value();
            results.send($"{text.split(" ").count} words");
            client.wake();
        }));
    }

    # A worker still holds what it captured until it ends, and the test's
    # leak check counts it.
    shutdown(): Result<void, ResponseError> {
        for (var worker in workers) {
            worker.join();
        }
        return Result<void, ResponseError>.ok();
    }

    woken() {
        while (true) {
            var result = results.try_receive();
            if (result.is_err()) {
                return;
            }
            client.log_message(lsp.MESSAGE_INFO, result.value());
        }
    }
}

[Test]
brings_work_from_other_threads_back_through_wake() {
    var inbound = Channel<lsp.Inbound>();
    var outgoing = Channel<String>();
    var exit_code = Channel<int>();
    var server = async.Thread.spawn(() => {
        exit_code.send(lsp.serve<Counter>((client) => Counter(client), inbound, outgoing));
    });
    var messages: String[] = [
        INITIALIZE,
        "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":"
            + "{\"uri\":\"file:///a\",\"languageId\":\"x\",\"version\":1,\"text\":\"one two three\"}}}"
    ];
    for (var message in messages) {
        inbound.send(copy(lsp.Inbound.Message(json.parse(message).value())));
    }
    var initialized = json.parse(outgoing.receive_for(5000).value()).value();
    expect_equal(initialized["id"].as_int().value(), 1);
    var logged = json.parse(outgoing.receive_for(5000).value()).value();
    expect_equal(logged["method"].as_string().value(), "window/logMessage");
    expect_equal(logged["params"]["message"].as_string().value(), "3 words");
    for (var message in [SHUTDOWN, EXIT]) {
        inbound.send(copy(lsp.Inbound.Message(json.parse(message).value())));
    }
    expect_equal(exit_code.receive_for(5000).value(), 0);
    # The thread still holds what it captured until it ends, and the leak
    # check counts it.
    server.join();
}

[Test]
sends_requests_to_the_client_and_drops_their_answers() {
    var outgoing = Channel<String>();
    var client = lsp.Client(outgoing, Channel<lsp.Inbound>());
    client.watch_files("pep-files", "**/*.pep");
    client.refresh_inlay_hints();
    var messages = messages_in(outgoing);
    expect_equal(messages[0]["id"].as_int().value(), 1);
    expect_equal(messages[0]["method"].as_string().value(), "client/registerCapability");
    var registration = messages[0]["params"]["registrations"][0];
    expect_equal(registration["registerOptions"]["watchers"][0]["globPattern"].as_string().value(), "**/*.pep");
    expect_equal(messages[1]["id"].as_int().value(), 2);
    expect_equal(messages[1]["method"].as_string().value(), "workspace/inlayHint/refresh");

    var output = Channel<String>();
    run_session([INITIALIZE, "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}", EXIT], output);
    expect_equal(messages_in(output).count, 1 as ulong);
}

# ── URIs ─────────────────────────────────────────────────────────────────

[Test]
converts_file_uris_and_paths() {
    expect_equal(lsp.uri_to_path("file:///home/me/a%20b.pep").value(), "/home/me/a b.pep");
    expect_equal(lsp.uri_to_path("file:///c%3A/src/a.pep").value(), "c:/src/a.pep");
    expect_equal(lsp.uri_to_path("file://localhost/x").value(), "/x");
    expect_true(lsp.uri_to_path("untitled:Untitled-1").is_empty());
    expect_true(lsp.uri_to_path("file://server/share/x").is_empty());
    expect_equal(lsp.path_to_uri("/home/me/a b.pep"), "file:///home/me/a%20b.pep");
    expect_equal(lsp.path_to_uri("C:\\src\\é.pep"), "file:///C%3A/src/%C3%A9.pep");
}
