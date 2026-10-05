# pepper-lsp

A [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
framework for [Pepper](https://github.com/justinboswell/pepper), in the style
of Rust's [tower-lsp](https://github.com/ebkalderon/tower-lsp). Use it to
write a language server for any language in Pepper. Pepper's own server,
`pep-lsp`, is built on it.

The package is the module `lsp`:

- **`LanguageServer`**: a trait with one method per request and notification.
  Only `initialize` is required. Every other request answers
  `METHOD_NOT_FOUND` until the server defines it, and every other
  notification is ignored. `request` and `notification` catch methods the
  trait does not name.
- **`serve_stdio`** and **`serve`** run the message loop. They handle the
  lifecycle (`initialize`, `shutdown`, `exit`), decode each message's
  parameters into typed structs, and answer bad parameters with
  `INVALID_PARAMS`.
- **`Client`**: how the server talks back, with `publish_diagnostics`,
  `log_message`, `show_message` and `send_notification`.
- **`TextDocument`**: an open document's text, kept in step with the
  client's changes (full or incremental). It converts protocol positions,
  which count UTF-16 columns, to and from byte offsets.
- **Protocol types**: `Position`, `Range`, `Diagnostic`, `Hover`,
  `CompletionItem` and the rest, with snake_case properties written under
  the protocol's camelCase keys. Empty optionals are left out of what the
  server sends.

```pepper
import lsp;
import [ResponseError] from lsp;

struct Hello {
    var client: lsp.Client;

    construct(client: lsp.Client) {
        this.client = client;
    }
}

extend Hello with lsp.LanguageServer {
    initialize(params: lsp.InitializeParams): Result<lsp.InitializeResult, ResponseError> {
        var result = lsp.InitializeResult();
        result.capabilities.hover_provider = Optional<bool>.Value(true);
        return Result<lsp.InitializeResult, ResponseError>.ok(result);
    }

    hover(params: lsp.TextDocumentPositionParams): Result<lsp.Hover?, ResponseError> {
        var hover = lsp.Hover(lsp.MarkupContent(lsp.MARKDOWN, "Hello!"));
        return Result<lsp.Hover?, ResponseError>.ok(Optional<lsp.Hover>.Value(hover));
    }
}

main(): int {
    return lsp.serve_stdio<Hello>((client) => Hello(client));
}
```

`examples/hello` is a complete server. It keeps documents in sync,
reports a warning at each `TODO`, and answers hovers.

## Using it

Add the package to `pep.toml`:

```toml
[dependencies]
lsp = { github = "justinboswell/pepper-lsp", branch = "main" }
```

## How it runs

`serve` handles messages one at a time, in the order they arrive. A
server's state therefore needs no locks, and a `didChange` is always
applied before the request that follows it. Because of this,
`$/cancelRequest` has nothing to cancel and goes to `notification`.

## Not yet

- Requests from the server to the client, such as
  `workspace/configuration` and `window/showMessageRequest`. Their
  responses are ignored for now.
- Typed methods for semantic tokens, signature help, and the other
  requests `pep-lsp` doesn't use yet. They reach `request` as JSON.

## Tests

```sh
tests/run.sh path/to/pepper
```

This runs the `[Test]` functions in `tests/lsp_test.pep`, which include
whole sessions driven through `serve` in memory, and builds the example.
