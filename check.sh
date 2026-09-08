#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p .build/checks
swiftc -swift-version 5 -parse-as-library Sources/Allowance/Usage.swift Sources/Allowance/Model.swift Checks/Runner.swift -o .build/checks/usage-checks
.build/checks/usage-checks
