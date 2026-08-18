<h1 align="left">
  <img src="Documentation/Assets/cidrwalk-icon.png" alt="cidrwalk icon" width="75" height="75" valign="middle">
  &nbsp;cidrwalk
</h1>

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FRouteObjects%2Fcidrwalk%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/RouteObjects/cidrwalk)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FRouteObjects%2Fcidrwalk%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/RouteObjects/cidrwalk)

`cidrwalk` is a small Swift command-line example built on
[`swift-cidr`](https://github.com/RouteObjects/swift-cidr). It demonstrates
CIDR summarization with explicit input meaning instead of guessing from loosely
typed strings.

The command is intentionally narrow and teaching-oriented:

- `addresses` summarizes two CIDR-qualified host endpoints with `/32` or `/128`.
- `networks` summarizes the envelope covering two whole CIDR network prefixes.

Both inputs must be from the same IP address family. Reversed input order is
normalized at the CLI boundary before calling into `swift-cidr`.

Version 0.2 adopts `swift-cidr` 0.5's RFC 5952 IPv6 spelling for list, tree,
and JSON output. IPv6 values are compressed deterministically, for example
`2001:db8::1/128`, while aggregation semantics and the CLI grammar remain
unchanged.

## CIDR Aggregation

CIDR summarization converts an inclusive address range, or the envelope around
two network prefixes, into the smallest ordered set of aligned CIDR prefixes.
The result may be one prefix when the inputs align cleanly, or several prefixes
when the range starts or ends inside a larger boundary.

The `addresses` subcommand requires `/32` for IPv4 and `/128` for IPv6 because
those prefix lengths identify exact host endpoints. The `networks` subcommand
accepts CIDR network prefixes and summarizes the full envelope that covers both
inputs, including adjacent, nested, or reversed networks.

## Usage

### Homebrew

Install the released command-line tool from the RouteObjects tap on macOS or
Linux. Homebrew pours a prebuilt binary; no Swift toolchain or Xcode is required
at install time.

```bash
brew install RouteObjects/tap/cidrwalk
cidrwalk --version
```

### Address Endpoints

Use `addresses` when the inputs are host endpoints. Prefix notation is required,
and only host-length prefix lengths are accepted.

```bash
cidrwalk addresses 192.168.1.1/32 192.168.1.2/32
```

```text
192.168.1.1/32
192.168.1.2/32
```

IPv6 host endpoints use `/128`:

```bash
cidrwalk addresses 2001:db8::1/128 2001:db8::f/128
```

```text
2001:db8::1/128
2001:db8::2/127
2001:db8::4/126
2001:db8::8/125
```

### Network Prefixes

Use `networks` when the inputs are CIDR network prefixes. The output covers both
complete input networks, including reversed, nested, or adjacent inputs.

```bash
cidrwalk networks 192.0.2.0/24 192.0.3.0/24
```

```text
192.0.2.0/23
```

### JSON

JSON output is available with `--output json`:

```bash
cidrwalk addresses 192.168.1.1/32 192.168.1.189/32 --output json
```

```json
{
  "family" : "IPv4",
  "inputs" : [
    "192.168.1.1/32",
    "192.168.1.189/32"
  ],
  "mode" : "addresses",
  "prefixes" : [
    "192.168.1.1/32",
    "192.168.1.2/31",
    "192.168.1.4/30",
    "192.168.1.8/29",
    "192.168.1.16/28",
    "192.168.1.32/27",
    "192.168.1.64/26",
    "192.168.1.128/27",
    "192.168.1.160/28",
    "192.168.1.176/29",
    "192.168.1.184/30",
    "192.168.1.188/31"
  ],
  "rangeEnd" : "192.168.1.189/32",
  "rangeStart" : "192.168.1.1/32"
}
```

### Tree

Tree output is available with `--output tree`. Indentation is based on
prefix-length depth within the summarized result; it is a teaching
visualization, not a proportional address-space diagram.

```bash
cidrwalk addresses 2001:db8::1/128 2001:db8::8/128 --output tree
```

```text
2001:db8::1/128
                2001:db8::2/127
                                2001:db8::4/126
2001:db8::8/128
```

### Build From Source

Clone the repository and run the executable with SwiftPM:

```bash
git clone https://github.com/RouteObjects/cidrwalk.git
cd cidrwalk
swift run cidrwalk --help
```

The 0.2 package accepts `swift-cidr` versions in the `0.5.x` line
(`>= 0.5.0` and `< 0.6.0`). This protects the command's tested serialization
contract from an unreviewed pre-1.0 minor update. Building requires Swift 6.1
or newer.

## Release Archives

Each release provides native macOS and Linux archives for arm64 and x86-64.
Every archive contains the `cidrwalk` executable, `LICENSE`, and
`THIRD_PARTY_NOTICES.txt`. Linux executables statically include the Swift
runtime and are exercised in a clean Ubuntu 22.04 container without Swift.
The release also includes `SHA256SUMS` covering all four archives.

## Testing

Use the repository test wrapper:

```bash
./scripts/test.sh
```

The wrapper still runs `swift test`. It only adds the Swift Testing framework
and runtime paths needed by standalone Command Line Tools installations where
plain `swift test` cannot locate `Testing.framework`.

Maintainers can validate a committed release candidate from a clean worktree:

```bash
./scripts/check-release.sh 0.2.0
```

The release workflow's manual dispatch builds and inspects the same four
artifacts without creating a GitHub Release. A verified signed tag creates a
draft Release for separate review and publication.
