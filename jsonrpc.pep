# JSON-RPC 2.0, as the Language Server Protocol uses it: errors and the
# codes they carry.

import json;
import [JsonValue] from json;

## The request was not valid JSON.
export const PARSE_ERROR = -32700;
## The message was not a valid request.
export const INVALID_REQUEST = -32600;
## No handler for the method.
export const METHOD_NOT_FOUND = -32601;
## The parameters did not match the method.
export const INVALID_PARAMS = -32602;
## The server failed while handling the request.
export const INTERNAL_ERROR = -32603;
## A request other than `initialize` arrived before it.
export const SERVER_NOT_INITIALIZED = -32002;
## The server cancelled the request.
export const REQUEST_CANCELLED = -32800;
## The document changed while the request ran, so its answer is stale.
export const CONTENT_MODIFIED = -32801;
## The request failed though it was valid.
export const REQUEST_FAILED = -32803;

## The error a request answers with instead of a result.
export struct ResponseError {
    ## One of the codes above, or a server's own.
    var code: int;
    ## What went wrong, for a person to read.
    var message: String;
    ## More about the error, sent as is; Empty sends none.
    var data: JsonValue?;

    ## Creates an error.
    ##
    ## @param code the error code
    ## @param message what went wrong
    construct(code: int = INTERNAL_ERROR, message: String = "") {
        this.code = code;
        this.message = message;
        this.data = Optional<JsonValue>.Empty;
    }

    ## The error for a method the server does not handle.
    ##
    ## @param method the method's name
    ## @returns a `METHOD_NOT_FOUND` error naming it
    static method_not_found(method: String): ResponseError {
        return ResponseError(METHOD_NOT_FOUND, $"method not found: {method}");
    }

    ## The error for parameters that do not match the method.
    ##
    ## @param message what is wrong with them
    ## @returns an `INVALID_PARAMS` error
    static invalid_params(message: String): ResponseError {
        return ResponseError(INVALID_PARAMS, message);
    }

    ## The error for a request the server failed to handle.
    ##
    ## @param message what went wrong
    ## @returns an `INTERNAL_ERROR` error
    static internal(message: String): ResponseError {
        return ResponseError(INTERNAL_ERROR, message);
    }

    ## The error as JSON, the `error` member of a response.
    ##
    ## @returns the error object
    to_json(): JsonValue {
        var out = JsonValue.object();
        out["code"] = JsonValue.Integer(code as long);
        out["message"] = JsonValue.String(message);
        if (data is Value(more)) {
            out["data"] = more;
        }
        return out;
    }
}
