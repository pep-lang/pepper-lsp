## A Language Server Protocol framework: write a language server for any
## language in Pepper, in the style of Rust's tower-lsp.
##
## A server is a struct that has the `LanguageServer` trait: `initialize`,
## which says what the server can do, and a method for each request and
## notification it handles. `serve_stdio` runs it, reading the client's
## messages from standard input and writing answers to standard output;
## the `Client` it gets sends notifications such as diagnostics.
## `TextDocument` keeps an open document's text and converts protocol
## positions (UTF-16 columns) to byte offsets.
##
## @example
##     import lsp;
##     import [ResponseError] from lsp;
##
##     struct Hello {
##         var client: lsp.Client;
##     }
##
##     extend Hello with lsp.LanguageServer {
##         initialize(params: lsp.InitializeParams): Result<lsp.InitializeResult, ResponseError> {
##             var result = lsp.InitializeResult();
##             result.capabilities.hover_provider = Optional<bool>.Value(true);
##             return Result<lsp.InitializeResult, ResponseError>.ok(result);
##         }
##
##         hover(params: lsp.TextDocumentPositionParams): Result<lsp.Hover?, ResponseError> {
##             var hover = lsp.Hover(lsp.MarkupContent(lsp.MARKDOWN, "Hello!"));
##             return Result<lsp.Hover?, ResponseError>.ok(Optional<lsp.Hover>.Value(hover));
##         }
##     }
##
##     main(): int {
##         return lsp.serve_stdio<Hello>((client) => Hello(client));
##     }
export * from "document";
export * from "jsonrpc";
export * from "server";
export * from "transport";
export * from "types";
export * from "uri";
