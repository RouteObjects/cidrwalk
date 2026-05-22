<h1 align="left">
  <img src="Documentation/Assets/cidrwalk-icon.png" alt="cidrwalk icon" width="75" height="75" valign="middle">
  &nbsp;cidrwalk
</h1>

`cidrwalk` is a small Swift command-line example built on
[`swift-cidr`](https://github.com/RouteObjects/swift-cidr). It demonstrates
CIDR summarization with explicit input meaning instead of guessing from loosely
typed strings.

The command is intentionally narrow and teaching-oriented:

- `addresses` summarizes two CIDR-qualified host endpoints with `/32` or `/128`.
- `networks` summarizes the envelope covering two whole CIDR network prefixes.

Both inputs must be from the same IP address family. Reversed input order is
normalized at the CLI boundary before calling into `swift-cidr`.

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

Clone the repository and run the executable with SwiftPM:

```bash
git clone https://github.com/RouteObjects/cidrwalk.git
cd cidrwalk
swift run cidrwalk --help
```

### Address Endpoints

Use `addresses` when the inputs are host endpoints. Prefix notation is required,
and only host-length prefix lengths are accepted.

```bash
swift run cidrwalk addresses 192.168.1.1/32 192.168.1.2/32
```

```text
192.168.1.1/32
192.168.1.2/32
```

IPv6 host endpoints use `/128`:

```bash
swift run cidrwalk addresses 2001:db8::1/128 2001:db8::f/128
```

### Network Prefixes

Use `networks` when the inputs are CIDR network prefixes. The output covers both
complete input networks, including reversed, nested, or adjacent inputs.

```bash
swift run cidrwalk networks 192.0.2.0/24 192.0.3.0/24
```

```text
192.0.2.0/23
```

### JSON

JSON output is available with `--output json`:

```bash
swift run cidrwalk addresses 192.168.1.1/32 192.168.1.189/32 --output json
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

## Testing

Use the repository test wrapper:

```bash
./scripts/test.sh
```

The wrapper still runs `swift test`. It only adds the Swift Testing framework
and runtime paths needed by standalone Command Line Tools installations where
plain `swift test` cannot locate `Testing.framework`.
