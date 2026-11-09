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
import Foundation
import Testing
@testable import cidrwalk

@Test("Root command exposes release version")
func rootCommandExposesReleaseVersion() {
    #expect(CIDRWalk.version == "0.3.0")
}

@Test("Root command accepts long and short version flags")
func rootCommandAcceptsVersionFlags() throws {
    let long = try CIDRWalk.parse(["--version"])
    let short = try CIDRWalk.parse(["-v"])

    #expect(long.showVersion)
    #expect(short.showVersion)
}

@Test("Addresses command summarizes IPv4 host endpoints as a line list")
func addressesSummarizesIPv4HostEndpointsAsList() throws {
    let startAddress = try CIDRWalk.parseHostEndpoint("192.168.1.1/32", label: "start")
    let endAddress = try CIDRWalk.parseHostEndpoint("192.168.1.2/32", label: "end")

    let output = try CIDRWalk.summarizeAddresses(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .list
    )

    #expect(output == """
    192.168.1.1/32
    192.168.1.2/32
    """)
}

@Test("Addresses command summarizes IPv4 host endpoints as a tree")
func addressesSummarizesIPv4HostEndpointsAsTree() throws {
    let startAddress = try CIDRWalk.parseHostEndpoint("192.0.2.1/32", label: "start")
    let endAddress = try CIDRWalk.parseHostEndpoint("192.0.2.6/32", label: "end")

    let output = try CIDRWalk.summarizeAddresses(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .tree
    )

    #expect(output == """
    192.0.2.1/32
                 192.0.2.2/31
                 192.0.2.4/31
    192.0.2.6/32
    """)
}

@Test("Addresses command summarizes IPv6 host endpoints as a line list")
func addressesSummarizesIPv6HostEndpointsAsList() throws {
    let startAddress = try CIDRWalk.parseHostEndpoint("2001:db8::1/128", label: "start")
    let endAddress = try CIDRWalk.parseHostEndpoint("2001:db8::f/128", label: "end")

    let output = try CIDRWalk.summarizeAddresses(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .list
    )

    #expect(output == """
    2001:db8::1/128
    2001:db8::2/127
    2001:db8::4/126
    2001:db8::8/125
    """)
}

@Test("Addresses command summarizes IPv6 host endpoints as an exact tree")
func addressesSummarizesIPv6HostEndpointsAsExactTree() throws {
    let startAddress = try CIDRWalk.parseHostEndpoint("2001:db8::1/128", label: "start")
    let endAddress = try CIDRWalk.parseHostEndpoint("2001:db8::8/128", label: "end")

    let output = try CIDRWalk.summarizeAddresses(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .tree
    )

    #expect(output == """
    2001:db8::1/128
                    2001:db8::2/127
                                    2001:db8::4/126
    2001:db8::8/128
    """)
}

@Test("Addresses command normalizes reversed host endpoints")
func addressesNormalizesReversedHostEndpoints() throws {
    let startAddress = try CIDRWalk.parseHostEndpoint("192.0.2.2/32", label: "start")
    let endAddress = try CIDRWalk.parseHostEndpoint("192.0.2.1/32", label: "end")

    let output = try CIDRWalk.summarizeAddresses(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .list
    )

    #expect(output == """
    192.0.2.1/32
    192.0.2.2/32
    """)
}

@Test("Addresses command rejects mixed-family input")
func addressesRejectsMixedFamilies() throws {
    let startAddress = try CIDRWalk.parseHostEndpoint("192.0.2.1/32", label: "start")
    let endAddress = try CIDRWalk.parseHostEndpoint("2001:db8::1/128", label: "end")

    #expect(throws: Error.self) {
        try CIDRWalk.summarizeAddresses(
            startAddress: startAddress,
            endAddress: endAddress,
            output: .list
        )
    }
}

@Test("Addresses command rejects bare addresses")
func addressesRejectsBareAddresses() {
    #expect(throws: Error.self) {
        try CIDRWalk.parseHostEndpoint("192.0.2.1", label: "start")
    }
}

@Test("Addresses command rejects non-host prefix lengths")
func addressesRejectsNonHostPrefixLengths() {
    #expect(throws: Error.self) {
        try CIDRWalk.parseHostEndpoint("192.0.2.1/24", label: "start")
    }

    #expect(throws: Error.self) {
        try CIDRWalk.parseHostEndpoint("2001:db8::1/64", label: "start")
    }
}

@Test("Networks command summarizes adjacent IPv4 networks")
func networksSummarizesAdjacentIPv4Networks() throws {
    let firstNetwork = try CIDRWalk.parseNetwork("192.0.2.0/24", label: "first")
    let secondNetwork = try CIDRWalk.parseNetwork("192.0.3.0/24", label: "second")

    let output = try CIDRWalk.summarizeNetworks(
        firstNetwork: firstNetwork,
        secondNetwork: secondNetwork,
        output: .list
    )

    #expect(output == "192.0.2.0/23")
}

@Test("Networks command normalizes reversed network inputs")
func networksNormalizesReversedInputs() throws {
    let firstNetwork = try CIDRWalk.parseNetwork("192.0.3.0/24", label: "first")
    let secondNetwork = try CIDRWalk.parseNetwork("192.0.2.0/24", label: "second")

    let output = try CIDRWalk.summarizeNetworks(
        firstNetwork: firstNetwork,
        secondNetwork: secondNetwork,
        output: .list
    )

    #expect(output == "192.0.2.0/23")
}

@Test(
    "Networks command rejects containment in either input order",
    arguments: [
        ("10.0.0.0/24", "10.0.0.0/25"),
        ("10.0.0.0/24", "10.0.0.128/25"),
        ("2001:db8::/126", "2001:db8::/127"),
        ("2001:db8::/126", "2001:db8::2/127"),
        ("0.0.0.0/0", "10.0.0.0/24"),
        ("::/0", "2001:db8::/64"),
    ]
)
func networksRejectsContainment(outer: String, inner: String) throws {
    for (first, second) in [(outer, inner), (inner, outer)] {
        try expectNetworkValidationError(
            first: first,
            second: second,
            message: "\(outer) contains \(inner); first and second must not contain one another."
        )
    }
}

@Test(
    "Networks command rejects identical and canonically equivalent networks",
    arguments: [
        ("10.0.0.0/24", "10.0.0.0/24", "10.0.0.0/24"),
        ("2001:db8::/126", "2001:db8::/126", "2001:db8::/126"),
        ("10.0.0.1/24", "10.0.0.254/24", "10.0.0.0/24"),
        ("2001:db8::1/126", "2001:db8::3/126", "2001:db8::/126"),
        ("0.0.0.0/0", "0.0.0.0/0", "0.0.0.0/0"),
        ("::/0", "::/0", "::/0"),
    ]
)
func networksRejectsEquivalentInputs(first: String, second: String, canonical: String) throws {
    for (firstText, secondText) in [(first, second), (second, first)] {
        try expectNetworkValidationError(
            first: firstText,
            second: secondText,
            message: "first and second must be different networks (both are \(canonical))."
        )
    }
}

@Test("Networks command summarizes adjacent IPv6 networks")
func networksSummarizesAdjacentIPv6Networks() throws {
    let firstNetwork = try CIDRWalk.parseNetwork("2001:db8::/127", label: "first")
    let secondNetwork = try CIDRWalk.parseNetwork("2001:db8::2/127", label: "second")

    let output = try CIDRWalk.summarizeNetworks(
        firstNetwork: firstNetwork,
        secondNetwork: secondNetwork,
        output: .list
    )

    #expect(output == "2001:db8::/126")
}

@Test("IPv6 JSON output uses the exact RFC 5952 serialization contract")
func ipv6JSONOutputUsesExactRFC5952Serialization() throws {
    let startAddress = try CIDRWalk.parseHostEndpoint("2001:db8::1/128", label: "start")
    let endAddress = try CIDRWalk.parseHostEndpoint("2001:db8::3/128", label: "end")

    let output = try CIDRWalk.summarizeAddresses(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .json
    )

    #expect(output == """
    {
      "family" : "IPv6",
      "inputs" : [
        "2001:db8::1/128",
        "2001:db8::3/128"
      ],
      "mode" : "addresses",
      "prefixes" : [
        "2001:db8::1/128",
        "2001:db8::2/127"
      ],
      "rangeEnd" : "2001:db8::3/128",
      "rangeStart" : "2001:db8::1/128"
    }
    """)
}

@Test("Networks command rejects malformed input")
func networksRejectsMalformedInput() {
    #expect(throws: Error.self) {
        try CIDRWalk.parseNetwork("not-a-network", label: "first")
    }
}

@Test("Networks command rejects mixed-family input")
func networksRejectsMixedFamilies() throws {
    for (first, second) in [
        ("192.0.2.0/24", "2001:db8::/64"),
        ("2001:db8::/64", "192.0.2.0/24"),
    ] {
        try expectNetworkValidationError(
            first: first,
            second: second,
            message: "first and second must use the same address family"
        )
    }
}

@Test("JSON output includes mode, family, inputs, range, and prefixes")
func jsonOutputIncludesSemanticContext() throws {
    let startAddress = try CIDRWalk.parseHostEndpoint("10.0.0.1/32", label: "start")
    let endAddress = try CIDRWalk.parseHostEndpoint("10.0.0.1/32", label: "end")

    let output = try CIDRWalk.summarizeAddresses(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .json
    )

    #expect(output.contains(#""family" : "IPv4""#))
    #expect(output.contains(#""inputs" : ["#))
    #expect(output.contains(#""mode" : "addresses""#))
    #expect(output.contains(#""prefixes" : ["#))
    #expect(output.contains(#""rangeEnd" : "10.0.0.1/32""#))
    #expect(output.contains(#""rangeStart" : "10.0.0.1/32""#))
    #expect(output.contains(#""10.0.0.1/32""#))
}

@Test("Addresses command accepts tree output format")
func addressesAcceptsTreeOutputFormat() throws {
    let command = try Addresses.parse([
        "192.0.2.1/32",
        "192.0.2.2/32",
        "--output",
        "tree"
    ])

    #expect(command.output == .tree)
}

@Test("Root command rejects positional inputs without a subcommand")
func rootCommandRejectsPositionalInputsWithoutSubcommand() {
    #expect(throws: Error.self) {
        _ = try CIDRWalk.parse(["192.0.2.1/32", "192.0.2.2/32"])
    }
}

// Decode all JSON fields to verify source prefix context independently of rendering.
@Test(
    "Network JSON retains source prefixes and orders boundaries independently of input order",
    arguments: [
        (
            "IPv4", "10.0.0.0/24", "10.0.2.0/25",
            "10.0.0.0/24", "10.0.2.127/25",
            ["10.0.0.0/23", "10.0.2.0/25"]
        ),
        (
            "IPv6", "2001:db8::/126", "2001:db8::8/127",
            "2001:db8::/126", "2001:db8::9/127",
            ["2001:db8::/125", "2001:db8::8/127"]
        ),
        (
            "IPv4", "192.0.2.0/24", "192.0.3.0/24",
            "192.0.2.0/24", "192.0.3.255/24",
            ["192.0.2.0/23"]
        ),
        (
            "IPv6", "2001:db8::/127", "2001:db8::2/127",
            "2001:db8::/127", "2001:db8::3/127",
            ["2001:db8::/126"]
        ),
        (
            "IPv4", "192.0.2.0/32", "192.0.2.1/32",
            "192.0.2.0/32", "192.0.2.1/32",
            ["192.0.2.0/31"]
        ),
        (
            "IPv6", "2001:db8::/128", "2001:db8::1/128",
            "2001:db8::/128", "2001:db8::1/128",
            ["2001:db8::/127"]
        ),
    ]
)
func networkJSONPreservesContext(
    family: String,
    lowerNetwork: String,
    upperNetwork: String,
    expectedStart: String,
    expectedEnd: String,
    expectedPrefixes: [String]
) throws {
    for inputs in [[lowerNetwork, upperNetwork], [upperNetwork, lowerNetwork]] {
        let first = try CIDRWalk.parseNetwork(inputs[0], label: "first")
        let second = try CIDRWalk.parseNetwork(inputs[1], label: "second")
        let output = try CIDRWalk.summarizeNetworks(
            firstNetwork: first,
            secondNetwork: second,
            output: .json
        )
        let data = Data(output.utf8)
        let payload = try JSONDecoder().decode(NetworkJSONPayload.self, from: data)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(Set(object.keys) == Set(["mode", "family", "inputs", "rangeStart", "rangeEnd", "prefixes"]))
        #expect(payload.mode == "networks")
        #expect(payload.family == family)
        #expect(payload.inputs == inputs)
        #expect(payload.rangeStart == expectedStart)
        #expect(payload.rangeEnd == expectedEnd)
        #expect(payload.prefixes == expectedPrefixes)
    }
}

private struct NetworkJSONPayload: Decodable {
    let mode: String
    let family: String
    let inputs: [String]
    let rangeStart: String
    let rangeEnd: String
    let prefixes: [String]
}

// Validate every output mode without changing process-global stdout or stderr.
private func expectNetworkValidationError(first: String, second: String, message: String) throws {
    let firstNetwork = try CIDRWalk.parseNetwork(first, label: "first")
    let secondNetwork = try CIDRWalk.parseNetwork(second, label: "second")

    for output in [OutputFormat.list, .tree, .json] {
        do {
            _ = try CIDRWalk.summarizeNetworks(
                firstNetwork: firstNetwork,
                secondNetwork: secondNetwork,
                output: output
            )
            Issue.record("Expected a validation error for \(first), \(second), and \(output)")
        } catch let error as ValidationError {
            #expect(error.message == message)
        }
    }
}
