import Testing
@testable import cidrwalk

@Test("Summarizes an IPv4 range as a line list")
func summarizesIPv4RangeAsList() throws {
    let startAddress = try Cidrwalk.parseAddress("192.168.1.1", label: "start")
    let endAddress = try Cidrwalk.parseAddress("192.168.1.2", label: "end")

    let output = try Cidrwalk.summarize(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .list
    )

    #expect(output == """
    192.168.1.1/32
    192.168.1.2/32
    """)
}

@Test("Summarizes an IPv6 range as a line list")
func summarizesIPv6RangeAsList() throws {
    let startAddress = try Cidrwalk.parseAddress("2001:db8::1", label: "start")
    let endAddress = try Cidrwalk.parseAddress("2001:db8::f", label: "end")

    let output = try Cidrwalk.summarize(
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

@Test("Renders JSON output with family and prefixes")
func rendersJSONOutput() throws {
    let startAddress = try Cidrwalk.parseAddress("10.0.0.1", label: "start")
    let endAddress = try Cidrwalk.parseAddress("10.0.0.1", label: "end")

    let output = try Cidrwalk.summarize(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .json
    )

    #expect(output.contains(#""family" : "IPv4""#))
    #expect(output.contains(#""prefixes" : ["#))
    #expect(output.contains(#""10.0.0.1/32""#))
}

@Test("Rejects mixed-family input")
func rejectsMixedFamilies() throws {
    let startAddress = try Cidrwalk.parseAddress("192.0.2.1", label: "start")
    let endAddress = try Cidrwalk.parseAddress("2001:db8::1", label: "end")

    #expect(throws: Error.self) {
        try Cidrwalk.summarize(
            startAddress: startAddress,
            endAddress: endAddress,
            output: .list
        )
    }
}

@Test("Rejects invalid input")
func rejectsInvalidInput() throws {
    #expect(throws: Error.self) {
        try Cidrwalk.parseAddress("not-an-ip-address", label: "start")
    }
}

@Test("Reversed ranges are normalized before summarization")
func reversedRangesAreNormalized() throws {
    let startAddress = try Cidrwalk.parseAddress("192.0.2.2", label: "start")
    let endAddress = try Cidrwalk.parseAddress("192.0.2.1", label: "end")

    let output = try Cidrwalk.summarize(
        startAddress: startAddress,
        endAddress: endAddress,
        output: .list
    )

    #expect(output == """
    192.0.2.1/32
    192.0.2.2/32
    """)
}
