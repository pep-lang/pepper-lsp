# The smallest useful server: answers every hover with a greeting and
# reports a warning on each line containing "TODO".
#
#     pepper build -I <folder holding lsp> examples/hello/main.pep -o hello-lsp

import lsp;
import [ResponseError] from lsp;

struct Hello {
    var client: lsp.Client;
    var documents: HashMap<String, lsp.TextDocument>;

    construct(client: lsp.Client) {
        this.client = client;
        this.documents = HashMap<String, lsp.TextDocument>();
    }

    # Warns about each "TODO" in the document.
    check(document: lsp.TextDocument) {
        var diagnostics = Array<lsp.Diagnostic>();
        long from = 0;
        while (true) {
            var at = document.text.find("TODO", from as ulong);
            if (at < 0) {
                break;
            }
            var range = document.range_of(at as ulong, at as ulong + 4);
            diagnostics.append(lsp.Diagnostic(range, "a TODO is left", lsp.SEVERITY_WARNING));
            from = at + 4;
        }
        client.publish_diagnostics(document.uri, diagnostics, Optional<int>.Value(document.version));
    }
}

extend Hello with lsp.LanguageServer {
    initialize(params: lsp.InitializeParams): Result<lsp.InitializeResult, ResponseError> {
        var result = lsp.InitializeResult();
        result.capabilities.text_document_sync = Optional<lsp.TextDocumentSyncOptions>.Value(
            lsp.TextDocumentSyncOptions(lsp.SYNC_INCREMENTAL)
        );
        result.capabilities.hover_provider = Optional<bool>.Value(true);
        return Result<lsp.InitializeResult, ResponseError>.ok(result);
    }

    did_open(params: lsp.DidOpenTextDocumentParams) {
        var document = lsp.TextDocument.opened(params.text_document);
        documents[document.uri] = document;
        check(document);
    }

    did_change(params: lsp.DidChangeTextDocumentParams) {
        var document = documents.try_get(params.text_document.uri);
        if (document.is_empty()) {
            return;
        }
        document.value().apply_changes(params);
        check(document.value());
    }

    did_close(params: lsp.DidCloseTextDocumentParams) {
        documents.remove(params.text_document.uri);
    }

    hover(params: lsp.TextDocumentPositionParams): Result<lsp.Hover?, ResponseError> {
        var hover = lsp.Hover(lsp.MarkupContent(lsp.MARKDOWN, "Hello from **Pepper**!"));
        return Result<lsp.Hover?, ResponseError>.ok(Optional<lsp.Hover>.Value(hover));
    }
}

main(): int {
    return lsp.serve_stdio<Hello>((client) => Hello(client));
}
