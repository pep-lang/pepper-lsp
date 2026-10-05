# The protocol's data types: the parameters and results of the methods
# `LanguageServer` handles, named as the specification names them, with
# snake_case properties written under their camelCase keys.
#
# An Empty optional property is left out of what the server sends. Numbers
# the specification spells as enumerations are `int`s with constants below.

import json;
import [JsonValue] from json;
import serialize;
import [Name, Required] from serialize;

# ── Enumerations ─────────────────────────────────────────────────────────

## `TextDocumentSyncKind.None`: the server does not want document changes.
export const SYNC_NONE = 0;
## `TextDocumentSyncKind.Full`: each change sends the whole document.
export const SYNC_FULL = 1;
## `TextDocumentSyncKind.Incremental`: each change sends the edited ranges.
export const SYNC_INCREMENTAL = 2;

## `DiagnosticSeverity.Error`.
export const SEVERITY_ERROR = 1;
## `DiagnosticSeverity.Warning`.
export const SEVERITY_WARNING = 2;
## `DiagnosticSeverity.Information`.
export const SEVERITY_INFORMATION = 3;
## `DiagnosticSeverity.Hint`.
export const SEVERITY_HINT = 4;

## `MessageType.Error`, for `Client.log_message` and `Client.show_message`.
export const MESSAGE_ERROR = 1;
## `MessageType.Warning`.
export const MESSAGE_WARNING = 2;
## `MessageType.Info`.
export const MESSAGE_INFO = 3;
## `MessageType.Log`.
export const MESSAGE_LOG = 4;

## `MarkupKind.PlainText`.
export const PLAIN_TEXT = "plaintext";
## `MarkupKind.Markdown`.
export const MARKDOWN = "markdown";

## `FileChangeType.Created`.
export const FILE_CREATED = 1;
## `FileChangeType.Changed`.
export const FILE_CHANGED = 2;
## `FileChangeType.Deleted`.
export const FILE_DELETED = 3;

## `SymbolKind` values, for `DocumentSymbol.kind`.
export const SYMBOL_FILE = 1;
## `SymbolKind.Module`.
export const SYMBOL_MODULE = 2;
## `SymbolKind.Namespace`.
export const SYMBOL_NAMESPACE = 3;
## `SymbolKind.Package`.
export const SYMBOL_PACKAGE = 4;
## `SymbolKind.Class`.
export const SYMBOL_CLASS = 5;
## `SymbolKind.Method`.
export const SYMBOL_METHOD = 6;
## `SymbolKind.Property`.
export const SYMBOL_PROPERTY = 7;
## `SymbolKind.Field`.
export const SYMBOL_FIELD = 8;
## `SymbolKind.Constructor`.
export const SYMBOL_CONSTRUCTOR = 9;
## `SymbolKind.Enum`.
export const SYMBOL_ENUM = 10;
## `SymbolKind.Interface`.
export const SYMBOL_INTERFACE = 11;
## `SymbolKind.Function`.
export const SYMBOL_FUNCTION = 12;
## `SymbolKind.Variable`.
export const SYMBOL_VARIABLE = 13;
## `SymbolKind.Constant`.
export const SYMBOL_CONSTANT = 14;
## `SymbolKind.String`.
export const SYMBOL_STRING = 15;
## `SymbolKind.Number`.
export const SYMBOL_NUMBER = 16;
## `SymbolKind.Boolean`.
export const SYMBOL_BOOLEAN = 17;
## `SymbolKind.Array`.
export const SYMBOL_ARRAY = 18;
## `SymbolKind.Object`.
export const SYMBOL_OBJECT = 19;
## `SymbolKind.Key`.
export const SYMBOL_KEY = 20;
## `SymbolKind.Null`.
export const SYMBOL_NULL = 21;
## `SymbolKind.EnumMember`.
export const SYMBOL_ENUM_MEMBER = 22;
## `SymbolKind.Struct`.
export const SYMBOL_STRUCT = 23;
## `SymbolKind.Event`.
export const SYMBOL_EVENT = 24;
## `SymbolKind.Operator`.
export const SYMBOL_OPERATOR = 25;
## `SymbolKind.TypeParameter`.
export const SYMBOL_TYPE_PARAMETER = 26;

## `CompletionItemKind` values, for `CompletionItem.kind`.
export const COMPLETION_TEXT = 1;
## `CompletionItemKind.Method`.
export const COMPLETION_METHOD = 2;
## `CompletionItemKind.Function`.
export const COMPLETION_FUNCTION = 3;
## `CompletionItemKind.Constructor`.
export const COMPLETION_CONSTRUCTOR = 4;
## `CompletionItemKind.Field`.
export const COMPLETION_FIELD = 5;
## `CompletionItemKind.Variable`.
export const COMPLETION_VARIABLE = 6;
## `CompletionItemKind.Class`.
export const COMPLETION_CLASS = 7;
## `CompletionItemKind.Interface`.
export const COMPLETION_INTERFACE = 8;
## `CompletionItemKind.Module`.
export const COMPLETION_MODULE = 9;
## `CompletionItemKind.Property`.
export const COMPLETION_PROPERTY = 10;
## `CompletionItemKind.Unit`.
export const COMPLETION_UNIT = 11;
## `CompletionItemKind.Value`.
export const COMPLETION_VALUE = 12;
## `CompletionItemKind.Enum`.
export const COMPLETION_ENUM = 13;
## `CompletionItemKind.Keyword`.
export const COMPLETION_KEYWORD = 14;
## `CompletionItemKind.Snippet`.
export const COMPLETION_SNIPPET = 15;
## `CompletionItemKind.Color`.
export const COMPLETION_COLOR = 16;
## `CompletionItemKind.File`.
export const COMPLETION_FILE = 17;
## `CompletionItemKind.Reference`.
export const COMPLETION_REFERENCE = 18;
## `CompletionItemKind.Folder`.
export const COMPLETION_FOLDER = 19;
## `CompletionItemKind.EnumMember`.
export const COMPLETION_ENUM_MEMBER = 20;
## `CompletionItemKind.Constant`.
export const COMPLETION_CONSTANT = 21;
## `CompletionItemKind.Struct`.
export const COMPLETION_STRUCT = 22;
## `CompletionItemKind.Event`.
export const COMPLETION_EVENT = 23;
## `CompletionItemKind.Operator`.
export const COMPLETION_OPERATOR = 24;
## `CompletionItemKind.TypeParameter`.
export const COMPLETION_TYPE_PARAMETER = 25;

## `InlayHintKind.Type`.
export const INLAY_TYPE = 1;
## `InlayHintKind.Parameter`.
export const INLAY_PARAMETER = 2;

## `CodeActionKind.QuickFix`.
export const QUICK_FIX = "quickfix";
## `CodeActionKind.Refactor`.
export const REFACTOR = "refactor";
## `CodeActionKind.Source`.
export const SOURCE = "source";

# ── Basic structures ─────────────────────────────────────────────────────

## A place in a document: a zero-based line, and a zero-based column in
## UTF-16 code units (see `TextDocument` to convert to byte offsets).
export struct Position {
    ## The line.
    [Required]
    var line: int;
    ## The column, in UTF-16 code units.
    [Required]
    var character: int;

    ## Creates a position.
    ##
    ## @param line the zero-based line
    ## @param character the zero-based UTF-16 column
    construct(line: int = 0, character: int = 0) {
        this.line = line;
        this.character = character;
    }
}

## The text from `start` up to, not including, `end`.
export struct Range {
    ## The first position.
    [Required]
    var start: Position;
    ## The position just past the last.
    [Required]
    var end: Position;

    ## Creates a range.
    ##
    ## @param start the first position
    ## @param end the position past the last
    construct(start: Position = Position(), end: Position = Position()) {
        this.start = start;
        this.end = end;
    }
}

## A range in a document named by URI.
export struct Location {
    ## The document.
    [Required]
    var uri: String;
    ## The range in it.
    [Required]
    var range: Range;

    ## Creates a location.
    ##
    ## @param uri the document
    ## @param range the range in it
    construct(uri: String = "", range: Range = Range()) {
        this.uri = uri;
        this.range = range;
    }
}

## Replaces the text of `range` with `new_text`.
export struct TextEdit {
    ## The text replaced; an empty range inserts.
    var range: Range;
    ## The new text; empty deletes.
    [Name("newText")]
    var new_text: String;

    ## Creates an edit.
    ##
    ## @param range the text replaced
    ## @param new_text the text put in its place
    construct(range: Range = Range(), new_text: String = "") {
        this.range = range;
        this.new_text = new_text;
    }
}

## Edits to several documents, keyed by URI.
export struct WorkspaceEdit {
    ## Each document's edits.
    var changes: HashMap<String, Array<TextEdit>>;

    ## Creates an empty edit.
    construct() {
        this.changes = HashMap<String, Array<TextEdit>>();
    }

    ## Adds an edit to the document `uri`.
    ##
    ## @param uri the document
    ## @param edit the edit
    add(uri: String, edit: TextEdit) {
        var edits = changes.try_get(uri);
        if (edits is Value(existing)) {
            existing.append(edit);
            return;
        }
        changes[uri] = [edit];
    }
}

## Text with a format for the client to render.
export struct MarkupContent {
    ## `PLAIN_TEXT` or `MARKDOWN`.
    var kind: String;
    ## The text.
    var value: String;

    ## Creates markup.
    ##
    ## @param kind `PLAIN_TEXT` or `MARKDOWN`
    ## @param value the text
    construct(kind: String = MARKDOWN, value: String = "") {
        this.kind = kind;
        this.value = value;
    }
}

## Names a document.
export struct TextDocumentIdentifier {
    ## The document's URI.
    [Required]
    var uri: String;
}

## Names a document at a version.
export struct VersionedTextDocumentIdentifier {
    ## The document's URI.
    [Required]
    var uri: String;
    ## The version, which goes up with each change.
    [Required]
    var version: int;
}

## A document the client opened.
export struct TextDocumentItem {
    ## The document's URI.
    [Required]
    var uri: String;
    ## The language, such as `pepper`.
    [Required]
    [Name("languageId")]
    var language_id: String;
    ## The version, which goes up with each change.
    [Required]
    var version: int;
    ## The whole text.
    [Required]
    var text: String;
}

## A position in a document: the parameters of most requests about code.
export struct TextDocumentPositionParams {
    ## The document.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
    ## The position in it.
    [Required]
    var position: Position;
}

# ── Lifecycle ────────────────────────────────────────────────────────────

## Who the client or server is.
export struct ClientInfo {
    ## The program's name.
    var name: String;
    ## Its version, if it says.
    var version: String?;
}

## A folder open in the client's workspace.
export struct WorkspaceFolder {
    ## The folder's URI.
    var uri: String;
    ## Its name in the client.
    var name: String;
}

## The parameters of `initialize`.
export struct InitializeParams {
    ## The client's process, so the server can exit if it dies.
    [Name("processId")]
    var process_id: long?;
    ## The client's name and version.
    [Name("clientInfo")]
    var client_info: ClientInfo?;
    ## The workspace's root folder (deprecated by the protocol in favor of
    ## `workspace_folders`).
    [Name("rootUri")]
    var root_uri: String?;
    ## The folders open in the workspace.
    [Name("workspaceFolders")]
    var workspace_folders: Array<WorkspaceFolder>?;
    ## Options the client's extension passes as is.
    [Name("initializationOptions")]
    var initialization_options: JsonValue?;
    ## What the client supports, as the client sent it.
    var capabilities: JsonValue?;
}

## Completion settings in `ServerCapabilities`.
export struct CompletionOptions {
    ## Characters that start completion, such as `.`.
    [Name("triggerCharacters")]
    var trigger_characters: Array<String>?;
    ## Whether the server answers `completionItem/resolve`.
    [Name("resolveProvider")]
    var resolve_provider: bool?;
}

## Text synchronization settings in `ServerCapabilities`.
export struct TextDocumentSyncOptions {
    ## Whether the server wants `didOpen` and `didClose`.
    [Name("openClose")]
    var open_close: bool;
    ## `SYNC_NONE`, `SYNC_FULL` or `SYNC_INCREMENTAL`.
    var change: int;

    ## Creates settings.
    ##
    ## @param change how changes are sent
    construct(change: int = SYNC_FULL) {
        this.open_close = true;
        this.change = change;
    }
}

## What the server can do, the answer to `initialize`. Each feature the
## server leaves Empty (or false) is one the client does not ask for.
export struct ServerCapabilities {
    ## How documents are synchronized.
    [Name("textDocumentSync")]
    var text_document_sync: TextDocumentSyncOptions?;
    ## Whether the server answers `textDocument/hover`.
    [Name("hoverProvider")]
    var hover_provider: bool?;
    ## Completion settings; Empty means no completion.
    [Name("completionProvider")]
    var completion_provider: CompletionOptions?;
    ## Whether the server answers `textDocument/definition`.
    [Name("definitionProvider")]
    var definition_provider: bool?;
    ## Whether the server answers `textDocument/references`.
    [Name("referencesProvider")]
    var references_provider: bool?;
    ## Whether the server answers `textDocument/documentSymbol`.
    [Name("documentSymbolProvider")]
    var document_symbol_provider: bool?;
    ## Whether the server answers `textDocument/codeAction`.
    [Name("codeActionProvider")]
    var code_action_provider: bool?;
    ## Whether the server answers `textDocument/formatting`.
    [Name("documentFormattingProvider")]
    var document_formatting_provider: bool?;
    ## Whether the server answers `textDocument/rename`.
    [Name("renameProvider")]
    var rename_provider: bool?;
    ## Whether the server answers `textDocument/inlayHint`.
    [Name("inlayHintProvider")]
    var inlay_hint_provider: bool?;
    ## Capabilities this struct does not name, merged in as is (for
    ## example `{"semanticTokensProvider": ...}`).
    [Name("experimental")]
    var experimental: JsonValue?;
}

## The answer to `initialize`.
export struct InitializeResult {
    ## What the server can do.
    var capabilities: ServerCapabilities;
    ## The server's name and version.
    [Name("serverInfo")]
    var server_info: ClientInfo?;

    ## Creates a result with no capabilities, for the server to fill in.
    construct() {
        this.capabilities = ServerCapabilities();
    }
}

# ── Document synchronization ─────────────────────────────────────────────

## The parameters of `textDocument/didOpen`.
export struct DidOpenTextDocumentParams {
    ## The document opened, with its text.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentItem;
}

## One change to a document: the new text of `range`, or the whole new
## text when `range` is Empty.
export struct TextDocumentContentChangeEvent {
    ## The text replaced; Empty replaces the whole document.
    var range: Range?;
    ## The new text.
    [Required]
    var text: String;
}

## The parameters of `textDocument/didChange`.
export struct DidChangeTextDocumentParams {
    ## The document and its new version.
    [Required]
    [Name("textDocument")]
    var text_document: VersionedTextDocumentIdentifier;
    ## The changes, in the order to apply them.
    [Required]
    [Name("contentChanges")]
    var content_changes: Array<TextDocumentContentChangeEvent>;
}

## The parameters of `textDocument/didSave`.
export struct DidSaveTextDocumentParams {
    ## The document saved.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
    ## The text, when the client was asked to include it.
    var text: String?;
}

## The parameters of `textDocument/didClose`.
export struct DidCloseTextDocumentParams {
    ## The document closed.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
}

## A watched file that changed.
export struct FileEvent {
    ## The file.
    [Required]
    var uri: String;
    ## `FILE_CREATED`, `FILE_CHANGED` or `FILE_DELETED`.
    [Required]
    [Name("type")]
    var change: int;
}

## The parameters of `workspace/didChangeWatchedFiles`.
export struct DidChangeWatchedFilesParams {
    ## The changes.
    [Required]
    var changes: Array<FileEvent>;
}

## The parameters of `workspace/didChangeConfiguration`.
export struct DidChangeConfigurationParams {
    ## The settings, as the client sent them.
    var settings: JsonValue?;
}

# ── Diagnostics and messages ─────────────────────────────────────────────

## More about a diagnostic, at another place.
export struct DiagnosticRelatedInformation {
    ## Where.
    var location: Location;
    ## What it says.
    var message: String;
}

## A problem the server reports in a document.
export struct Diagnostic {
    ## Where.
    [Required]
    var range: Range;
    ## `SEVERITY_ERROR`, `SEVERITY_WARNING`, `SEVERITY_INFORMATION` or
    ## `SEVERITY_HINT`.
    var severity: int?;
    ## The problem's code, such as a compiler error number.
    var code: String?;
    ## Who reports it, such as the server's name.
    var source: String?;
    ## What is wrong.
    [Required]
    var message: String;
    ## Places that explain it.
    [Name("relatedInformation")]
    var related_information: Array<DiagnosticRelatedInformation>?;
    ## Data the server gets back in a code action's context.
    var data: JsonValue?;

    ## Creates a diagnostic.
    ##
    ## @param range where
    ## @param message what is wrong
    ## @param severity one of the `SEVERITY_` constants
    construct(range: Range = Range(), message: String = "", severity: int = SEVERITY_ERROR) {
        this.range = range;
        this.message = message;
        this.severity = Optional<int>.Value(severity);
    }
}

## The parameters of `textDocument/publishDiagnostics`.
export struct PublishDiagnosticsParams {
    ## The document.
    var uri: String;
    ## The version the diagnostics are about, if known.
    var version: int?;
    ## Every diagnostic of the document; an empty array clears them.
    var diagnostics: Array<Diagnostic>;
}

## The parameters of `window/logMessage` and `window/showMessage`.
export struct MessageParams {
    ## One of the `MESSAGE_` constants.
    [Name("type")]
    var kind: int;
    ## The message.
    var message: String;
}

# ── Language features ────────────────────────────────────────────────────

## The answer to `textDocument/hover`.
export struct Hover {
    ## What to show.
    var contents: MarkupContent;
    ## The text the hover is about, to highlight.
    var range: Range?;

    ## Creates a hover.
    ##
    ## @param contents what to show
    construct(contents: MarkupContent = MarkupContent()) {
        this.contents = contents;
    }
}

## The parameters of `textDocument/completion`.
export struct CompletionParams {
    ## The document.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
    ## Where completion was asked for.
    [Required]
    var position: Position;
    ## How it was triggered, as the client sent it.
    var context: JsonValue?;
}

## One completion.
export struct CompletionItem {
    ## The text shown, and inserted unless `insert_text` or `text_edit` says
    ## otherwise.
    var label: String;
    ## One of the `COMPLETION_` constants.
    var kind: int?;
    ## A short description, such as a signature.
    var detail: String?;
    ## Documentation to show beside it.
    var documentation: MarkupContent?;
    ## The text inserted instead of `label`.
    [Name("insertText")]
    var insert_text: String?;
    ## An edit made instead of inserting.
    [Name("textEdit")]
    var text_edit: TextEdit?;
    ## The key the client sorts by instead of `label`.
    [Name("sortText")]
    var sort_text: String?;
    ## The text the client filters by instead of `label`.
    [Name("filterText")]
    var filter_text: String?;

    ## Creates an item.
    ##
    ## @param label the text shown and inserted
    ## @param kind one of the `COMPLETION_` constants
    construct(label: String = "", kind: int = COMPLETION_TEXT) {
        this.label = label;
        this.kind = Optional<int>.Value(kind);
    }
}

## The answer to `textDocument/completion`.
export struct CompletionList {
    ## Whether typing more should ask again rather than filter this list.
    [Name("isIncomplete")]
    var is_incomplete: bool;
    ## The completions.
    var items: Array<CompletionItem>;

    ## Creates a list.
    ##
    ## @param items the completions
    ## @param is_incomplete whether typing more should ask again
    construct(items: Array<CompletionItem> = Array<CompletionItem>(), is_incomplete: bool = false) {
        this.items = items;
        this.is_incomplete = is_incomplete;
    }
}

## The parameters of `textDocument/references`.
export struct ReferenceParams {
    ## The document.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
    ## The position of the name.
    [Required]
    var position: Position;
    ## `{"includeDeclaration": bool}`, as the client sent it.
    var context: JsonValue?;
}

## The parameters of `textDocument/documentSymbol`.
export struct DocumentSymbolParams {
    ## The document.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
}

## A declaration in a document's outline.
export struct DocumentSymbol {
    ## The name.
    var name: String;
    ## More, such as a signature.
    var detail: String?;
    ## One of the `SYMBOL_` constants.
    var kind: int;
    ## The whole declaration.
    var range: Range;
    ## The name, inside `range`.
    [Name("selectionRange")]
    var selection_range: Range;
    ## The declarations inside it.
    var children: Array<DocumentSymbol>;

    ## Creates a symbol.
    ##
    ## @param name the name
    ## @param kind one of the `SYMBOL_` constants
    ## @param range the whole declaration
    ## @param selection_range the name
    construct(
        name: String = "", kind: int = SYMBOL_VARIABLE, range: Range = Range(), selection_range: Range = Range()
    ) {
        this.name = name;
        this.kind = kind;
        this.range = range;
        this.selection_range = selection_range;
        this.children = Array<DocumentSymbol>();
    }
}

## The parameters of `textDocument/inlayHint`.
export struct InlayHintParams {
    ## The document.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
    ## The part of it shown.
    [Required]
    var range: Range;
}

## Text the client shows inside the code, such as an inferred type.
export struct InlayHint {
    ## Where.
    var position: Position;
    ## The text.
    var label: String;
    ## `INLAY_TYPE` or `INLAY_PARAMETER`.
    var kind: int?;
    ## A tooltip.
    var tooltip: MarkupContent?;
    ## Whether to put a space before it.
    [Name("paddingLeft")]
    var padding_left: bool?;
    ## Whether to put a space after it.
    [Name("paddingRight")]
    var padding_right: bool?;

    ## Creates a hint.
    ##
    ## @param position where
    ## @param label the text
    construct(position: Position = Position(), label: String = "") {
        this.position = position;
        this.label = label;
    }
}

## What a code action request is about.
export struct CodeActionContext {
    ## The diagnostics at the range.
    [Required]
    var diagnostics: Array<Diagnostic>;
    ## The kinds of action wanted; Empty means any.
    var only: Array<String>?;
}

## The parameters of `textDocument/codeAction`.
export struct CodeActionParams {
    ## The document.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
    ## The range selected.
    [Required]
    var range: Range;
    ## The diagnostics there.
    [Required]
    var context: CodeActionContext;
}

## A fix or refactoring the client can apply.
export struct CodeAction {
    ## What it does.
    var title: String;
    ## `QUICK_FIX`, `REFACTOR`, `SOURCE`, or a dotted refinement of one.
    var kind: String?;
    ## The diagnostics it fixes.
    var diagnostics: Array<Diagnostic>?;
    ## Whether it is the fix to apply by default.
    [Name("isPreferred")]
    var is_preferred: bool?;
    ## The edit it makes.
    var edit: WorkspaceEdit?;

    ## Creates an action.
    ##
    ## @param title what it does
    ## @param kind its kind
    construct(title: String = "", kind: String = QUICK_FIX) {
        this.title = title;
        this.kind = Optional<String>.Value(kind);
    }
}

## How to format.
export struct FormattingOptions {
    ## Spaces per tab.
    [Name("tabSize")]
    var tab_size: int;
    ## Whether to indent with spaces.
    [Name("insertSpaces")]
    var insert_spaces: bool;
}

## The parameters of `textDocument/formatting`.
export struct DocumentFormattingParams {
    ## The document.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
    ## How to format.
    [Required]
    var options: FormattingOptions;
}

## The parameters of `textDocument/rename`.
export struct RenameParams {
    ## The document.
    [Required]
    [Name("textDocument")]
    var text_document: TextDocumentIdentifier;
    ## The position of the name.
    [Required]
    var position: Position;
    ## The new name.
    [Required]
    [Name("newName")]
    var new_name: String;
}
