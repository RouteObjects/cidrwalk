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

import Testing
@testable import cidrwalk

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
    2001:db8:0:0:0:0:0:1/128
    2001:db8:0:0:0:0:0:2/127
    2001:db8:0:0:0:0:0:4/126
    2001:db8:0:0:0:0:0:8/125
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

@Test("Networks command summarizes nested IPv4 networks by envelope")
func networksSummarizesNestedIPv4NetworksByEnvelope() throws {
    let firstNetwork = try CIDRWalk.parseNetwork("10.0.0.0/24", label: "first")
    let secondNetwork = try CIDRWalk.parseNetwork("10.0.0.0/25", label: "second")

    let output = try CIDRWalk.summarizeNetworks(
        firstNetwork: firstNetwork,
        secondNetwork: secondNetwork,
        output: .list
    )

    #expect(output == "10.0.0.0/24")
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

    #expect(output == "2001:db8:0:0:0:0:0:0/126")
}

@Test("Networks command rejects malformed input")
func networksRejectsMalformedInput() {
    #expect(throws: Error.self) {
        try CIDRWalk.parseNetwork("not-a-network", label: "first")
    }
}

@Test("Networks command rejects mixed-family input")
func networksRejectsMixedFamilies() throws {
    let firstNetwork = try CIDRWalk.parseNetwork("192.0.2.0/24", label: "first")
    let secondNetwork = try CIDRWalk.parseNetwork("2001:db8::/64", label: "second")

    #expect(throws: Error.self) {
        try CIDRWalk.summarizeNetworks(
            firstNetwork: firstNetwork,
            secondNetwork: secondNetwork,
            output: .list
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

@Test("Root command rejects positional inputs without a subcommand")
func rootCommandRejectsPositionalInputsWithoutSubcommand() {
    #expect(throws: Error.self) {
        _ = try CIDRWalk.parse(["192.0.2.1/32", "192.0.2.2/32"])
    }
}
