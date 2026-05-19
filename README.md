# cidrwalk

`cidrwalk` is a small Swift command-line example built on
[`swift-cidr`](../swift-cidr). It summarizes an inclusive IPv4 or IPv6 address
range into the smallest ordered set of CIDR prefixes.

The command is intentionally narrow: it demonstrates calling
`IPNetwork<Family>.summarize(from:to:)` with two `IPAddress<Family>` values. Both
inputs must be valid IP addresses from the same address family. Reversed input
ranges are normalized before summarization.

## Usage

```bash
swift run cidrwalk 192.168.1.1 192.168.1.2
```

```text
192.168.1.1/32
192.168.1.2/32
```

JSON output is available with `--output json`:

```bash
swift run cidrwalk 10.0.0.1 10.0.0.1 --output json
```

```json
{
  "end" : "10.0.0.1/32",
  "family" : "IPv4",
  "prefixes" : [
    "10.0.0.1/32"
  ],
  "start" : "10.0.0.1/32"
}
```

IPv6 ranges use the same command shape:

```bash
swift run cidrwalk 2001:db8::1 2001:db8::f
```

## Testing

Use the repository test wrapper:

```bash
./scripts/test.sh
```

The wrapper still runs `swift test`. It only adds the Swift Testing framework
and runtime paths needed by standalone Command Line Tools installations where
plain `swift test` cannot locate `Testing.framework`.
