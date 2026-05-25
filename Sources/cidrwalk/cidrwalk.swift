//===----------------------------------------------------------------------===//
//
// This source file is part of the cidrwalk package.
//
// Copyright (c) 2026 Craig A. Munro
//
// Licensed under the Apache License, Version 2.0.
// See the LICENSE file for details.
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import CIDR
import Foundation

@main
struct CIDRWalk: ParsableCommand {
    static let version = "0.1.1"

    static let configuration = CommandConfiguration(
        commandName: "cidrwalk",
        abstract: "Summarize IPv4 or IPv6 CIDR inputs into the smallest ordered prefix set.",
        subcommands: [Addresses.self, Networks.self]
    )

    @Flag(
        name: [.customShort("v"), .customLong("version")],
        help: "Show the cidrwalk version."
    )
    var showVersion = false

    mutating func run() throws {
        guard showVersion else { return }
        print(Self.version)
    }
}

struct Addresses: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "addresses",
        abstract: "Summarize two CIDR-qualified host endpoints such as 192.0.2.1/32."
    )

    @Argument(help: "One IPv4 /32 or IPv6 /128 endpoint.")
    var start: String

    @Argument(help: "The other IPv4 /32 or IPv6 /128 endpoint.")
    var end: String

    @Option(name: .shortAndLong, help: "Output format: list or json.")
    var output: OutputFormat = .list

    mutating func run() throws {
        let startAddress = try CIDRWalk.parseHostEndpoint(start, label: "start")
        let endAddress = try CIDRWalk.parseHostEndpoint(end, label: "end")
        let lines = try CIDRWalk.summarizeAddresses(
            startAddress: startAddress,
            endAddress: endAddress,
            output: output
        )
        CIDRWalk.printIfNeeded(lines)
    }
}

struct Networks: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "networks",
        abstract: "Summarize the envelope covering two CIDR network prefixes such as 192.0.2.0/24."
    )

    @Argument(help: "One IPv4 or IPv6 CIDR network prefix.")
    var first: String

    @Argument(help: "The other IPv4 or IPv6 CIDR network prefix.")
    var second: String

    @Option(name: .shortAndLong, help: "Output format: list or json.")
    var output: OutputFormat = .list

    mutating func run() throws {
        let firstNetwork = try CIDRWalk.parseNetwork(first, label: "first")
        let secondNetwork = try CIDRWalk.parseNetwork(second, label: "second")
        let lines = try CIDRWalk.summarizeNetworks(
            firstNetwork: firstNetwork,
            secondNetwork: secondNetwork,
            output: output
        )
        CIDRWalk.printIfNeeded(lines)
    }
}

extension CIDRWalk {
    static func parseHostEndpoint(_ text: String, label: String) throws -> AnyIPAddress {
        guard text.contains("/") else {
            throw ValidationError("\(label) must include CIDR prefix notation, such as /32 or /128")
        }

        guard let address = AnyIPAddress(text) else {
            throw ValidationError("\(label) must be a valid IPv4 or IPv6 CIDR-qualified address")
        }

        switch address {
        case .v4(let value):
            guard value.prefixLength == .maximum else {
                throw ValidationError("\(label) must be an IPv4 host endpoint with /32 prefix length")
            }
        case .v6(let value):
            guard value.prefixLength == .maximum else {
                throw ValidationError("\(label) must be an IPv6 host endpoint with /128 prefix length")
            }
        }

        return address
    }

    static func parseNetwork(_ text: String, label: String) throws -> AnyIPNetwork {
        guard text.contains("/") else {
            throw ValidationError("\(label) must include CIDR prefix notation")
        }

        guard let network = AnyIPNetwork(text) else {
            throw ValidationError("\(label) must be a valid IPv4 or IPv6 CIDR network")
        }

        return network
    }

    static func summarizeAddresses(
        startAddress: AnyIPAddress,
        endAddress: AnyIPAddress,
        output: OutputFormat
    ) throws -> String {
        switch (startAddress, endAddress) {
        case (.v4(let start), .v4(let end)):
            let rangeStart = min(start, end)
            let rangeEnd = max(start, end)
            return try render(
                IPv4Network.summarize(from: rangeStart, to: rangeEnd).map(\.description),
                mode: .addresses,
                family: "IPv4",
                inputs: [start.description, end.description],
                rangeStart: rangeStart.description,
                rangeEnd: rangeEnd.description,
                output: output
            )
        case (.v6(let start), .v6(let end)):
            let rangeStart = min(start, end)
            let rangeEnd = max(start, end)
            return try render(
                IPv6Network.summarize(from: rangeStart, to: rangeEnd).map(\.description),
                mode: .addresses,
                family: "IPv6",
                inputs: [start.description, end.description],
                rangeStart: rangeStart.description,
                rangeEnd: rangeEnd.description,
                output: output
            )
        default:
            throw ValidationError("start and end must use the same address family")
        }
    }

    static func summarizeNetworks(
        firstNetwork: AnyIPNetwork,
        secondNetwork: AnyIPNetwork,
        output: OutputFormat
    ) throws -> String {
        switch (firstNetwork, secondNetwork) {
        case (.v4(let first), .v4(let second)):
            let rangeStart = first.first.address <= second.first.address ? first.first : second.first
            let rangeEnd = first.last.address >= second.last.address ? first.last : second.last
            return try render(
                IPv4Network.summarize(covering: first, and: second).map(\.description),
                mode: .networks,
                family: "IPv4",
                inputs: [first.description, second.description],
                rangeStart: rangeStart.description,
                rangeEnd: rangeEnd.description,
                output: output
            )
        case (.v6(let first), .v6(let second)):
            let rangeStart = first.first.address <= second.first.address ? first.first : second.first
            let rangeEnd = first.last.address >= second.last.address ? first.last : second.last
            return try render(
                IPv6Network.summarize(covering: first, and: second).map(\.description),
                mode: .networks,
                family: "IPv6",
                inputs: [first.description, second.description],
                rangeStart: rangeStart.description,
                rangeEnd: rangeEnd.description,
                output: output
            )
        default:
            throw ValidationError("first and second must use the same address family")
        }
    }

    static func printIfNeeded(_ lines: String) {
        guard !lines.isEmpty else { return }
        print(lines, terminator: lines.hasSuffix("\n") ? "" : "\n")
    }

    private static func render(
        _ prefixes: [String],
        mode: SummaryMode,
        family: String,
        inputs: [String],
        rangeStart: String,
        rangeEnd: String,
        output: OutputFormat
    ) throws -> String {
        switch output {
        case .list:
            return prefixes.joined(separator: "\n")
        case .json:
            let payload = SummaryPayload(
                mode: mode,
                family: family,
                inputs: inputs,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                prefixes: prefixes
            )
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

enum SummaryMode: String, Encodable {
    case addresses
    case networks
}

private struct SummaryPayload: Encodable {
    var mode: SummaryMode
    var family: String
    var inputs: [String]
    var rangeStart: String
    var rangeEnd: String
    var prefixes: [String]
}
