#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

VERSION="${1:-}"
[[ "${VERSION}" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] ||
    fail "Usage: scripts/check-release.sh MAJOR.MINOR.PATCH"

cd "${PACKAGE_ROOT}"

[[ -z "$(git status --short)" ]] ||
    fail "Commit or stash package changes before running the release check."

for required in \
    LICENSE \
    THIRD_PARTY_NOTICES.txt \
    "Documentation/ReleaseNotes/${VERSION}.md" \
    .github/workflows/ci.yml \
    .github/workflows/release.yml; do
    [[ -e "${required}" ]] || fail "Required release file is missing: ${required}"
done

grep -Fq "static let version = \"${VERSION}\"" Sources/cidrwalk/cidrwalk.swift ||
    fail "The executable version does not match ${VERSION}."
grep -Fq '.upToNextMinor(from: "0.5.0")' Package.swift ||
    fail "The swift-cidr requirement is not pinned to the 0.5 minor line."
grep -Fq '"revision" : "fd5116cef64544dc1f2bab9e93de4e1a7bb57dbb"' Package.resolved ||
    fail "Package.resolved does not contain the reviewed swift-cidr 0.5.0 revision."

while IFS= read -r swift_file; do
    grep -q 'SPDX-License-Identifier: Apache-2.0' "${swift_file}" ||
        fail "Apache license header is missing: ${swift_file}"
done < <(find Package.swift Sources Tests -name '*.swift' -type f -print)

"${SCRIPT_DIR}/audit-release-content.sh" tree
"${SCRIPT_DIR}/audit-release-content.sh" dependencies

git diff --check
swift package resolve
git diff --exit-code -- Package.resolved
swift build --product cidrwalk
"${SCRIPT_DIR}/test.sh"

if [[ "$(uname -s)" == "Linux" ]]; then
    swift build \
        -c release \
        --static-swift-stdlib \
        --product cidrwalk \
        -Xswiftc -debug-prefix-map \
        -Xswiftc "${PACKAGE_ROOT}=Source" \
        -Xcc "-ffile-prefix-map=${PACKAGE_ROOT}/.build=SwiftPMBuild"
else
    # Match the Darwin release workflow before auditing the public binary.
    swift build \
        -c release \
        --product cidrwalk \
        -Xswiftc -file-prefix-map \
        -Xswiftc "${PACKAGE_ROOT}/.build=SwiftPMBuild" \
        -Xswiftc -file-prefix-map \
        -Xswiftc "${PACKAGE_ROOT}=Source" \
        -Xcc "-ffile-prefix-map=${PACKAGE_ROOT}/.build=SwiftPMBuild" \
        -Xcc "-ffile-prefix-map=${PACKAGE_ROOT}=Source"
fi

binary="$(swift build -c release --show-bin-path)/cidrwalk"
if [[ "$(uname -s)" == "Linux" ]]; then
    strip --strip-unneeded "${binary}"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    strip -S -x "${binary}"
fi

[[ "$("${binary}" --version)" == "${VERSION}" ]] ||
    fail "The release executable version does not match ${VERSION}."
"${binary}" --help >/dev/null

actual_output="$(mktemp)"
expected_output="$(mktemp)"
trap 'rm -f -- "${actual_output}" "${expected_output}"' EXIT
"${binary}" addresses 2001:db8::1/128 2001:db8::3/128 >"${actual_output}"
printf '%s\n' '2001:db8::1/128' '2001:db8::2/127' >"${expected_output}"
cmp "${expected_output}" "${actual_output}"

"${SCRIPT_DIR}/audit-release-content.sh" binary "${binary}"

if [[ "$(uname -s)" == "Linux" ]]; then
    readelf -d "${binary}" >.build/release-elf-dynamic-section.txt
    if grep -E 'NEEDED.*(libswift|libFoundation|libdispatch|libBlocksRuntime)' \
        .build/release-elf-dynamic-section.txt; then
        fail "The executable still requires a Swift runtime shared library."
    fi
fi

[[ -z "$(git status --short)" ]] ||
    fail "Release checks changed the working tree."

printf 'cidrwalk %s release checks passed.\n' "${VERSION}"
