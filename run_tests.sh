#!/bin/bash
set -e

echo "Compilando e executando testes do vpdf..."

CACHE_DIR="${TMPDIR:-/tmp}/clang-cache"
mkdir -p "$CACHE_DIR"

swiftc -module-cache-path "$CACHE_DIR" \
    Sources/vpdf/Models/ConversionFormat.swift \
    Sources/vpdf/Models/AppError.swift \
    Sources/vpdf/Models/FileItem.swift \
    Sources/vpdf/Services/EncodingService.swift \
    Sources/vpdf/Services/FileSystemService.swift \
    Sources/vpdf/Services/ConversionService.swift \
    Tests/TestRunner.swift \
    -o "${TMPDIR:-/tmp}/vpdf_tests"

"${TMPDIR:-/tmp}/vpdf_tests"
