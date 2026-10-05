# The server side of the protocol: the `LanguageServer` trait a language
# implements, the `Client` it talks back through, and `serve`, which runs
# the message loop.

import io;
import json;
import [JsonValue] from json;
import "jsonrpc";
import "transport";
import "types";

## A language server: one method per request or notification of the
## protocol. Only `initialize` is required. Every other request answers
## `METHOD_NOT_FOUND` until the server defines it, and every other
## notification is ignored, so a server defines just what its
## `ServerCapabilities` promise.
##
## `serve` calls the methods one at a time, in the order the messages
## arrive, so a server's state needs no locks: a `did_change` is always
## applied before the request that follows it.
export trait LanguageServer {
    ## `initialize`: the first request. Says what the server can do.
    ##
    ## @param params who the client is and what it supports
    ## @returns the server's capabilities, or an error that ends the session
    initialize(params: InitializeParams): Result<InitializeResult, ResponseError>;

    ## `initialized`: the client has the server's capabilities.
    initialized() {}

    ## `shutdown`: the client is about to ask the server to exit; release
    ## what needs releasing.
    ##
    ## @returns Ok, or an error the client reports
    shutdown(): Result<void, ResponseError> {
        return Result<void, ResponseError>.ok();
    }

    ## `textDocument/didOpen`.
    ##
    ## @param params the document opened
    did_open(params: DidOpenTextDocumentParams) {}

    ## `textDocument/didChange`.
    ##
    ## @param params the document and its changes
    did_change(params: DidChangeTextDocumentParams) {}

    ## `textDocument/didSave`.
    ##
    ## @param params the document saved
    did_save(params: DidSaveTextDocumentParams) {}

    ## `textDocument/didClose`.
    ##
    ## @param params the document closed
    did_close(params: DidCloseTextDocumentParams) {}

    ## `workspace/didChangeWatchedFiles`.
    ##
    ## @param params the files that changed
    did_change_watched_files(params: DidChangeWatchedFilesParams) {}

    ## `workspace/didChangeConfiguration`.
    ##
    ## @param params the new settings
    did_change_configuration(params: DidChangeConfigurationParams) {}

    ## `textDocument/hover`.
    ##
    ## @param params the position hovered
    ## @returns what to show, or Empty for nothing
    hover(params: TextDocumentPositionParams): Result<Hover?, ResponseError> {
        return Result<Hover?, ResponseError>.err(ResponseError.method_not_found("textDocument/hover"));
    }

    ## `textDocument/completion`.
    ##
    ## @param params where completion was asked for
    ## @returns the completions, or Empty for none
    completion(params: CompletionParams): Result<CompletionList?, ResponseError> {
        return Result<CompletionList?, ResponseError>.err(ResponseError.method_not_found("textDocument/completion"));
    }

    ## `textDocument/definition`.
    ##
    ## @param params the position of a name
    ## @returns where it is declared; empty when nowhere known
    definition(params: TextDocumentPositionParams): Result<Array<Location>, ResponseError> {
        return Result<Array<Location>, ResponseError>.err(ResponseError.method_not_found("textDocument/definition"));
    }

    ## `textDocument/references`.
    ##
    ## @param params the position of a name
    ## @returns where it is used
    references(params: ReferenceParams): Result<Array<Location>, ResponseError> {
        return Result<Array<Location>, ResponseError>.err(ResponseError.method_not_found("textDocument/references"));
    }

    ## `textDocument/documentSymbol`.
    ##
    ## @param params the document
    ## @returns its outline
    document_symbol(params: DocumentSymbolParams): Result<Array<DocumentSymbol>, ResponseError> {
        return Result<Array<DocumentSymbol>, ResponseError>.err(
            ResponseError.method_not_found("textDocument/documentSymbol")
        );
    }

    ## `textDocument/inlayHint`.
    ##
    ## @param params the document and the range shown
    ## @returns the hints in the range
    inlay_hint(params: InlayHintParams): Result<Array<InlayHint>, ResponseError> {
        return Result<Array<InlayHint>, ResponseError>.err(ResponseError.method_not_found("textDocument/inlayHint"));
    }

    ## `textDocument/codeAction`.
    ##
    ## @param params the range and the diagnostics there
    ## @returns the actions that apply
    code_action(params: CodeActionParams): Result<Array<CodeAction>, ResponseError> {
        return Result<Array<CodeAction>, ResponseError>.err(ResponseError.method_not_found("textDocument/codeAction"));
    }

    ## `textDocument/formatting`.
    ##
    ## @param params the document and how to format it
    ## @returns the edits that format it
    formatting(params: DocumentFormattingParams): Result<Array<TextEdit>, ResponseError> {
        return Result<Array<TextEdit>, ResponseError>.err(ResponseError.method_not_found("textDocument/formatting"));
    }

    ## `textDocument/rename`.
    ##
    ## @param params the name and its new spelling
    ## @returns the edits that rename it, or Empty when it cannot be renamed
    rename(params: RenameParams): Result<WorkspaceEdit?, ResponseError> {
        return Result<WorkspaceEdit?, ResponseError>.err(ResponseError.method_not_found("textDocument/rename"));
    }

    ## Any request this trait has no method for, with its parameters as
    ## JSON.
    ##
    ## @param method the request's method
    ## @param params its parameters
    ## @returns the result, as JSON
    request(method: String, params: JsonValue): Result<JsonValue, ResponseError> {
        return Result<JsonValue, ResponseError>.err(ResponseError.method_not_found(method));
    }

    ## Any notification this trait has no method for, with its parameters
    ## as JSON. `$/` notifications the server ignores arrive here too.
    ##
    ## @param method the notification's method
    ## @param params its parameters
    notification(method: String, params: JsonValue) {}
}

## The server's way to talk to the client: notifications it sends on its
## own, such as diagnostics. Create one per session and pass it to the
## server, as `serve` does.
export struct Client {
    var _output: io.Writer;

    ## Creates a client writing to `output`.
    ##
    ## @param output the stream the client reads
    construct(output: io.Writer) {
        _output = output;
    }

    ## Sends `textDocument/publishDiagnostics`: the document's diagnostics,
    ## replacing those sent before.
    ##
    ## @param uri the document
    ## @param diagnostics every diagnostic of the document; empty clears them
    ## @param version the version they are about, if known
    publish_diagnostics(uri: String, diagnostics: Array<Diagnostic>, version: int? = Optional<int>.Empty) {
        var params = PublishDiagnosticsParams();
        params.uri = uri;
        params.diagnostics = diagnostics;
        params.version = version;
        send_notification("textDocument/publishDiagnostics", to_protocol_json(params));
    }

    ## Sends `window/logMessage`: a line for the client's log.
    ##
    ## @param kind one of the `MESSAGE_` constants
    ## @param message the line
    log_message(kind: int, message: String) {
        send_notification("window/logMessage", _message(kind, message));
    }

    ## Sends `window/showMessage`: a message the client shows its user.
    ##
    ## @param kind one of the `MESSAGE_` constants
    ## @param message the message
    show_message(kind: int, message: String) {
        send_notification("window/showMessage", _message(kind, message));
    }

    ## Sends any notification.
    ##
    ## @param method the method
    ## @param params its parameters
    send_notification(method: String, params: JsonValue) {
        var message = JsonValue.object();
        message["jsonrpc"] = JsonValue.String("2.0");
        message["method"] = JsonValue.String(method);
        message["params"] = params;
        _send(message);
    }

    _message(kind: int, message: String): JsonValue {
        var params = MessageParams();
        params.kind = kind;
        params.message = message;
        return to_protocol_json(params);
    }

    # Writes a message. A client that has gone away is not an error the
    # server can act on, so a failed write is dropped; the session ends at
    # the next read.
    _send(message: JsonValue) {
        write_message(_output, message);
    }
}

## Converts a protocol value to JSON as the protocol expects it: as
## `json.to_json` does, but leaving out the members whose value is null (an
## Empty optional), which the protocol treats as absent.
##
## @param value a value of one of the protocol's types
## @returns its JSON
export to_protocol_json<T>(value: T): JsonValue {
    return without_nulls(json.to_json(value));
}

## A copy of `value` without the object members whose value is null, at
## every depth. Array elements stay as they are.
##
## @param value the JSON
## @returns the JSON without null members
export without_nulls(value: JsonValue): JsonValue {
    if (value is Object(members)) {
        var out = JsonValue.object();
        for (var (key, member) in members) {
            if (!member.is_null()) {
                out[key] = without_nulls(member);
            }
        }
        return out;
    }
    if (value is Array(items)) {
        var out = Array<JsonValue>();
        for (var item in items) {
            out.append(without_nulls(item));
        }
        return JsonValue.array(out);
    }
    return value;
}

## Runs a language server over standard input and output until the client
## sends `exit`.
##
## @param make creates the server, given the client it talks back through
## @returns the process's exit code: 0 after `shutdown` then `exit`,
##     1 otherwise
export serve_stdio<S: LanguageServer>(make: (Client) => S): int {
    return serve<S>(make, io.File.stdin(), io.File.stdout());
}

## Runs a language server until the client sends `exit` or the input ends.
##
## Answers requests before `initialize` with `SERVER_NOT_INITIALIZED` and
## requests after `shutdown` with `INVALID_REQUEST`, and handles `exit`.
## Every other message goes to the server's method for it.
##
## @param make creates the server, given the client it talks back through
## @param input the stream the client writes
## @param output the stream the client reads
## @returns the process's exit code: 0 after `shutdown` then `exit`,
##     1 otherwise
export serve<S: LanguageServer>(make: (Client) => S, input: io.Reader, output: io.Writer): int {
    var client = Client(output);
    var server = make(client);
    var session = _Session<S>(server, client);
    var reader = MessageReader(input);
    while (true) {
        var message = reader.read();
        if (message.is_err()) {
            client.log_message(MESSAGE_ERROR, message.error());
            return 1;
        }
        if (message.value().is_empty()) {
            return 1;
        }
        var done = session.handle(message.value().value());
        if (done is Value(code)) {
            return code;
        }
    }
    return 1;
}

# The state of one session around the server: where it is in the
# protocol's lifecycle.
struct _Session<S: LanguageServer> {
    var server: S;
    var client: Client;
    var initialized: bool;
    var shut_down: bool;

    construct(server: S, client: Client) {
        this.server = server;
        this.client = client;
        this.initialized = false;
        this.shut_down = false;
    }

    # Handles one message; Value(exit code) when it was `exit`.
    handle(message: JsonValue): int? {
        var method_value = message["method"];
        var method = method_value.as_string();
        if (method.is_empty()) {
            # A response to a request the server sent; this framework sends
            # none yet.
            return Optional<int>.Empty;
        }
        var params = message.contains("params") ? message["params"] : JsonValue.Null;
        if (!message.contains("id")) {
            return notify(method.value(), params);
        }
        var id = message["id"];
        var answer = answer(method.value(), params);
        var response = JsonValue.object();
        response["jsonrpc"] = JsonValue.String("2.0");
        response["id"] = id;
        if (answer is Ok(result)) {
            response["result"] = result;
        } else {
            response["error"] = answer.error().to_json();
        }
        client._send(response);
        return Optional<int>.Empty;
    }

    # Answers a request.
    answer(method: String, params: JsonValue): Result<JsonValue, ResponseError> {
        if (method == "initialize") {
            if (initialized) {
                return Result<JsonValue, ResponseError>.err(
                    ResponseError(INVALID_REQUEST, "initialize was already sent")
                );
            }
            var decoded = json.from_json<InitializeParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            var result = server.initialize(decoded.value());
            if (result.is_err()) {
                return Result<JsonValue, ResponseError>.err(result.error());
            }
            initialized = true;
            return Result<JsonValue, ResponseError>.ok(to_protocol_json(result.value()));
        }
        if (!initialized) {
            return Result<JsonValue, ResponseError>.err(
                ResponseError(SERVER_NOT_INITIALIZED, $"{method} before initialize")
            );
        }
        if (shut_down) {
            return Result<JsonValue, ResponseError>.err(ResponseError(INVALID_REQUEST, $"{method} after shutdown"));
        }
        if (method == "shutdown") {
            shut_down = true;
            var result = server.shutdown();
            if (result.is_err()) {
                return Result<JsonValue, ResponseError>.err(result.error());
            }
            return Result<JsonValue, ResponseError>.ok(JsonValue.Null);
        }
        if (method == "textDocument/hover") {
            var decoded = json.from_json<TextDocumentPositionParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            return _encode<Hover?>(server.hover(decoded.value()));
        }
        if (method == "textDocument/completion") {
            var decoded = json.from_json<CompletionParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            return _encode<CompletionList?>(server.completion(decoded.value()));
        }
        if (method == "textDocument/definition") {
            var decoded = json.from_json<TextDocumentPositionParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            return _encode<Array<Location>>(server.definition(decoded.value()));
        }
        if (method == "textDocument/references") {
            var decoded = json.from_json<ReferenceParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            return _encode<Array<Location>>(server.references(decoded.value()));
        }
        if (method == "textDocument/documentSymbol") {
            var decoded = json.from_json<DocumentSymbolParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            return _encode<Array<DocumentSymbol>>(server.document_symbol(decoded.value()));
        }
        if (method == "textDocument/inlayHint") {
            var decoded = json.from_json<InlayHintParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            return _encode<Array<InlayHint>>(server.inlay_hint(decoded.value()));
        }
        if (method == "textDocument/codeAction") {
            var decoded = json.from_json<CodeActionParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            return _encode<Array<CodeAction>>(server.code_action(decoded.value()));
        }
        if (method == "textDocument/formatting") {
            var decoded = json.from_json<DocumentFormattingParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            return _encode<Array<TextEdit>>(server.formatting(decoded.value()));
        }
        if (method == "textDocument/rename") {
            var decoded = json.from_json<RenameParams>(params);
            if (decoded.is_err()) {
                return _invalid<JsonValue>(decoded.error());
            }
            return _encode<WorkspaceEdit?>(server.rename(decoded.value()));
        }
        return server.request(method, params);
    }

    # Handles a notification; Value(exit code) when it was `exit`.
    notify(method: String, params: JsonValue): int? {
        if (method == "exit") {
            return Optional<int>.Value(shut_down ? 0 : 1);
        }
        # Before `initialize` the protocol drops every notification but
        # `exit`.
        if (!initialized) {
            return Optional<int>.Empty;
        }
        if (method == "initialized") {
            server.initialized();
        } else if (method == "textDocument/didOpen") {
            var decoded = json.from_json<DidOpenTextDocumentParams>(params);
            if (decoded.is_err()) {
                _invalid_notification(method, decoded.error());
            } else {
                server.did_open(decoded.value());
            }
        } else if (method == "textDocument/didChange") {
            var decoded = json.from_json<DidChangeTextDocumentParams>(params);
            if (decoded.is_err()) {
                _invalid_notification(method, decoded.error());
            } else {
                server.did_change(decoded.value());
            }
        } else if (method == "textDocument/didSave") {
            var decoded = json.from_json<DidSaveTextDocumentParams>(params);
            if (decoded.is_err()) {
                _invalid_notification(method, decoded.error());
            } else {
                server.did_save(decoded.value());
            }
        } else if (method == "textDocument/didClose") {
            var decoded = json.from_json<DidCloseTextDocumentParams>(params);
            if (decoded.is_err()) {
                _invalid_notification(method, decoded.error());
            } else {
                server.did_close(decoded.value());
            }
        } else if (method == "workspace/didChangeWatchedFiles") {
            var decoded = json.from_json<DidChangeWatchedFilesParams>(params);
            if (decoded.is_err()) {
                _invalid_notification(method, decoded.error());
            } else {
                server.did_change_watched_files(decoded.value());
            }
        } else if (method == "workspace/didChangeConfiguration") {
            var decoded = json.from_json<DidChangeConfigurationParams>(params);
            if (decoded.is_err()) {
                _invalid_notification(method, decoded.error());
            } else {
                server.did_change_configuration(decoded.value());
            }
        } else {
            server.notification(method, params);
        }
        return Optional<int>.Empty;
    }

    # Logs a notification's parameters that did not decode, since a
    # notification has no answer to carry the error.
    _invalid_notification(method: String, error: json.JsonError) {
        client.log_message(MESSAGE_ERROR, $"{method}: invalid parameters: {error.message}");
    }
}

# The `INVALID_PARAMS` error for parameters that did not decode.
_invalid<T>(error: json.JsonError): Result<T, ResponseError> {
    return Result<T, ResponseError>.err(ResponseError.invalid_params(error.message));
}

# A handler's result as JSON.
_encode<T>(result: Result<T, ResponseError>): Result<JsonValue, ResponseError> {
    if (result.is_err()) {
        return Result<JsonValue, ResponseError>.err(result.error());
    }
    return Result<JsonValue, ResponseError>.ok(to_protocol_json(result.value()));
}
