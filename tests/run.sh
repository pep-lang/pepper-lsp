#!/usr/bin/env bash
# Runs the package's tests: the [Test] functions under tests/ with
# `pepper test`, then builds the hello example.
#
# Usage: tests/run.sh [path/to/pepper]   (default: pepper on PATH)
set -euxo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pepper="${1:-pepper}"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

cd "$build"
# The package is the module `lsp`: a folder of that name on the import path.
mkdir packages
ln -s "$root" packages/lsp
"$pepper" test -I packages "$root/tests"
"$pepper" build -I packages "$root/examples/hello/main.pep" -o hello
echo "all tests passed"
