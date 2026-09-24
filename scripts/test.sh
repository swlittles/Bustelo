#!/bin/bash
# The pure logic compiles alongside the tests, so no Xcode or XCTest is required.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc Sources/Bustelo/Session.swift Sources/Bustelo/NudgePolicy.swift Tests/BusteloTests/main.swift -o .build/bustelo-tests
.build/bustelo-tests
