#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

audit_temporary_file=""
audit_filtered_file=""

cleanup() {
    if [[ -n "${audit_temporary_file}" ]]; then
        rm -f -- "${audit_temporary_file}"
    fi
    if [[ -n "${audit_filtered_file}" ]]; then
        rm -f -- "${audit_filtered_file}"
    fi
}

trap cleanup EXIT

# Build expressions from fragments so the audit never satisfies its own
# searches. Matches stay out of logs because a match may itself be sensitive.
mac_home="/""Users/"
linux_home="/""home/[^/]+/"
private_var="/""private/var/"
file_url="file:""///"

private_key="-----BE""GIN (OPENSSH |RSA |EC |DSA |ENCRYPTED )?PRIVATE KEY-----"
aws_key="(A""KIA|A""SIA)[0-9A-Z]{16}"
github_token="gh""[pousr]_[A-Za-z0-9]{20,}"
github_pat="github""_pat_[A-Za-z0-9_]{20,}"
slack_token="xo""x[baprs]-[A-Za-z0-9-]{20,}"
api_key="sk""-(live|proj)-[A-Za-z0-9_-]{16,}"

audit_tracked_tree() {
    local status

    if git -C "${PACKAGE_ROOT}" grep --quiet -I -E \
        -e "${mac_home}" \
        -e "${linux_home}" \
        -e "${private_var}" \
        -e "${file_url}" \
        -- .; then
        fail "Tracked files contain a local absolute path."
    else
        status=$?
        [[ ${status} -eq 1 ]] || fail "Unable to audit tracked local paths."
    fi

    if git -C "${PACKAGE_ROOT}" grep --quiet -I -E \
        -e "${private_key}" \
        -e "${aws_key}" \
        -e "${github_token}" \
        -e "${github_pat}" \
        -e "${slack_token}" \
        -e "${api_key}" \
        -- .; then
        fail "Tracked files contain a credential or private-key marker."
    else
        status=$?
        [[ ${status} -eq 1 ]] || fail "Unable to audit tracked sensitive markers."
    fi
}

audit_dependency_notices() {
    local actual_pin_count
    local expected_pin_count=6

    # CHANGE: Bind the shipped notice inventory to the complete reviewed lockfile so a
    # transitive pin cannot change or appear without an explicit attribution update.
    actual_pin_count="$(grep -c '"identity" : ' "${PACKAGE_ROOT}/Package.resolved")"
    [[ "${actual_pin_count}" -eq "${expected_pin_count}" ]] ||
        fail "Package.resolved contains an unexpected number of dependency pins."

    while IFS='|' read -r identity name version revision; do
        grep -Fq "\"identity\" : \"${identity}\"" "${PACKAGE_ROOT}/Package.resolved" ||
            fail "Package.resolved is missing ${identity}."
        grep -Fq "\"version\" : \"${version}\"" "${PACKAGE_ROOT}/Package.resolved" ||
            fail "Package.resolved is missing ${identity} version ${version}."
        grep -Fq "\"revision\" : \"${revision}\"" "${PACKAGE_ROOT}/Package.resolved" ||
            fail "Package.resolved is missing ${identity} revision ${revision}."
        grep -Fq "${name} ${version}" "${PACKAGE_ROOT}/THIRD_PARTY_NOTICES.txt" ||
            fail "THIRD_PARTY_NOTICES.txt is missing ${name} ${version}."
        grep -Fq "Revision: ${revision}" "${PACKAGE_ROOT}/THIRD_PARTY_NOTICES.txt" ||
            fail "THIRD_PARTY_NOTICES.txt is missing revision ${revision}."
    done <<'EOF'
swift-argument-parser|Swift Argument Parser|1.7.1|626b5b7b2f45e1b0b1c6f4a309296d1d21d7311b
swift-atomics|Swift Atomics|1.3.0|b601256eab081c0f92f059e12818ac1d4f178ff7
swift-cidr|swift-cidr|0.5.0|fd5116cef64544dc1f2bab9e93de4e1a7bb57dbb
swift-collections|Swift Collections|1.5.1|fea17c02d767f46b23070fdfdacc28a03a39232a
swift-nio|SwiftNIO|2.100.0|57c0a08a331aaea9f5d7a932ad94ef43be942a95
swift-system|Swift System|1.6.4|7c6ad0fc39d0763e0b699210e4124afd5041c5df
EOF
}

audit_binary() {
    local binary="$1"
    local path_pattern
    local raw_path_pattern
    local status
    local upstream_runtime_path
    local upstream_toolchain_path

    [[ -f "${binary}" ]] || fail "Binary not found: ${binary}"
    command -v strings >/dev/null 2>&1 || fail "Required command not found: strings"

    audit_temporary_file="$(mktemp)"
    audit_filtered_file="$(mktemp)"
    # Inspect every data section on Darwin and Linux. Apple's default strings
    # selection omits Mach-O sections that GNU strings examines.
    LC_ALL=C strings -a "${binary}" >"${audit_temporary_file}"

    # Static Swift archives contain reviewed source paths from the official
    # toolchain and one Foundation runtime lookup path. Neither identifies the
    # release runner or this source checkout.
    upstream_toolchain_path="^/""home/build-user/swift(-experimental-string-processing)?/"
    upstream_runtime_path="^/""private/var/automount/$"
    grep -E -v \
        -e "${upstream_toolchain_path}" \
        -e "${upstream_runtime_path}" \
        "${audit_temporary_file}" >"${audit_filtered_file}"

    path_pattern="(${mac_home}|${linux_home}|${private_var}|/workspace(/|$)|/github/workspace(/|$)|/__w/|/builds?(/|$)|/runner/_work/|[.]build/)"
    if grep --quiet -E "${path_pattern}" "${audit_filtered_file}"; then
        fail "Release binary contains a workspace, home, or build path."
    else
        status=$?
        [[ ${status} -eq 1 ]] || fail "Unable to audit release binary paths."
    fi

    # Scan raw bytes for path families that have no reviewed static-runtime
    # exception so Darwin and Linux assembly enforce the same policy.
    raw_path_pattern="(${mac_home}|/workspace(/|$)|/github/workspace(/|$)|/__w/|/builds?(/|$)|/runner/_work/|[.]build/)"
    if LC_ALL=C grep -a --quiet -E "${raw_path_pattern}" "${binary}"; then
        fail "Release binary contains a workspace, home, or build path."
    else
        status=$?
        [[ ${status} -eq 1 ]] || fail "Unable to audit raw release binary paths."
    fi

    if grep --quiet -E \
        -e "${private_key}" \
        -e "${aws_key}" \
        -e "${github_token}" \
        -e "${github_pat}" \
        -e "${slack_token}" \
        -e "${api_key}" \
        "${audit_temporary_file}"; then
        fail "Release binary contains a credential or private-key marker."
    else
        status=$?
        [[ ${status} -eq 1 ]] || fail "Unable to audit release binary markers."
    fi

    cleanup
    audit_temporary_file=""
    audit_filtered_file=""
}

case "${1:-}" in
tree)
    [[ $# -eq 1 ]] || fail "Usage: audit-release-content.sh tree"
    audit_tracked_tree
    ;;
dependencies)
    [[ $# -eq 1 ]] || fail "Usage: audit-release-content.sh dependencies"
    audit_dependency_notices
    ;;
binary)
    [[ $# -eq 2 ]] || fail "Usage: audit-release-content.sh binary PATH"
    audit_binary "$2"
    ;;
*)
    fail "Usage: audit-release-content.sh {tree|dependencies|binary PATH}"
    ;;
esac
