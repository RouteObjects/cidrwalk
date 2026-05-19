import ArgumentParser
import CIDR
import Foundation

@main
struct Cidrwalk: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cidrwalk",
        abstract: "Summarize an inclusive IPv4 or IPv6 address range into CIDR prefixes."
    )

    @Argument(help: "The first IPv4 or IPv6 address in the inclusive range.")
    var start: String

    @Argument(help: "The last IPv4 or IPv6 address in the inclusive range.")
    var end: String

    @Option(name: .shortAndLong, help: "Output format: list or json.")
    var output: OutputFormat = .list

    mutating func run() throws {
        let startAddress = try Self.parseAddress(start, label: "start")
        let endAddress = try Self.parseAddress(end, label: "end")
        
        let lines = try Self.summarize(startAddress: startAddress, endAddress: endAddress, output: output)
        guard !lines.isEmpty else { return }
        print(lines, terminator: lines.hasSuffix("\n") ? "" : "\n")
    }

    static func summarize(startAddress: AnyIPAddress, endAddress: AnyIPAddress, output: OutputFormat) throws -> String {
        switch (startAddress, endAddress) {
        case (.v4(let start), .v4(let end)):
            let rangeStart = min(start, end)
            let rangeEnd = max(start, end)
            return try render(
                IPv4Network.summarize(from: rangeStart, to: rangeEnd),
                family: "IPv4",
                start: rangeStart.description,
                end: rangeEnd.description,
                output: output
            )
        case (.v6(let start), .v6(let end)):
            let rangeStart = min(start, end)
            let rangeEnd = max(start, end)
            return try render(
                IPv6Network.summarize(from: rangeStart, to: rangeEnd),
                family: "IPv6",
                start: rangeStart.description,
                end: rangeEnd.description,
                output: output
            )
        default:
            throw ValidationError("start and end must use the same address family")
        }
    }

    static func parseAddress(_ text: String, label: String) throws -> AnyIPAddress {
        guard let address = AnyIPAddress(text) else {
            throw ValidationError("\(label) must be a valid IPv4 or IPv6 address")
        }
        return address
    }

    private static func render<Network: IPPrefix>(
        _ networks: [Network],
        family: String,
        start: String,
        end: String,
        output: OutputFormat
    ) throws -> String {
        let prefixes = networks.map(\.description)

        switch output {
        case .list:
            return prefixes.joined(separator: "\n")
        case .json:
            let payload = SummaryPayload(family: family, start: start, end: end, prefixes: prefixes)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(payload)
            return String(decoding: data, as: UTF8.self)
        }
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case list
    case json
}

private struct SummaryPayload: Encodable {
    var family: String
    var start: String
    var end: String
    var prefixes: [String]
}
