//
//  DeviceStringParserTests.swift
//  HKImportTests
//

import Testing
@testable import HKImport

struct DeviceStringParserTests {

    // MARK: - Real export strings

    @Test func parseRealIPhoneDeviceString() {
        let input = "<<HKDevice: 0x6b879dfe0>, name:iPhone, manufacturer:Apple Inc., model:iPhone, hardware:iPhone16,2, software:18.3.2>"
        let result = DeviceStringParser.parse(input)

        #expect(result != nil)
        #expect(result?.name == "iPhone")
        #expect(result?.manufacturer == "Apple Inc.")
        #expect(result?.model == "iPhone")
        #expect(result?.hardwareVersion == "iPhone16,2")
        #expect(result?.softwareVersion == "18.3.2")
    }

    @Test func parseDeviceStringWithExtraFields() {
        // Real string with UDIDeviceIdentifier and creation date — those should be ignored
        let input = "<<HKDevice: 0x6b879dfe0>, name:iPhone, manufacturer:Apple Inc., model:iPhone, hardware:iPhone16,2, software:18.3.2, UDIDeviceIdentifier:8CDB3BDE-3CEA-4D85-9147-9F546392BDFC, creation date:2025-03-29 12:06:39 +0000>"
        let result = DeviceStringParser.parse(input)

        #expect(result != nil)
        #expect(result?.name == "iPhone")
        #expect(result?.manufacturer == "Apple Inc.")
        #expect(result?.model == "iPhone")
        #expect(result?.hardwareVersion == "iPhone16,2")
        #expect(result?.softwareVersion == "18.3.2")
    }

    @Test func parseAppleWatchDeviceString() {
        let input = "<<HKDevice: 0x3a0b1c2d0>, name:Apple Watch, manufacturer:Apple Inc., model:Watch, hardware:Watch7,3, software:11.3>"
        let result = DeviceStringParser.parse(input)

        #expect(result != nil)
        #expect(result?.name == "Apple Watch")
        #expect(result?.manufacturer == "Apple Inc.")
        #expect(result?.model == "Watch")
        #expect(result?.hardwareVersion == "Watch7,3")
        #expect(result?.softwareVersion == "11.3")
    }

    // MARK: - Nil / invalid inputs

    @Test func parseEmptyStringReturnsNil() {
        #expect(DeviceStringParser.parse("") == nil)
    }

    @Test func parseArbitraryStringReturnsNil() {
        #expect(DeviceStringParser.parse("just some random text") == nil)
    }

    @Test func parsePartialPrefixReturnsNil() {
        #expect(DeviceStringParser.parse("<<HKDevice: 0xabc>") == nil)
    }

    @Test func parseMissingClosingBracketReturnsNil() {
        #expect(DeviceStringParser.parse("<<HKDevice: 0xabc>, name:iPhone") == nil)
    }

    // MARK: - Partial fields

    @Test func parseDeviceStringWithOnlyName() {
        let input = "<<HKDevice: 0xabc>, name:WHOOP>"
        let result = DeviceStringParser.parse(input)

        #expect(result != nil)
        #expect(result?.name == "WHOOP")
        #expect(result?.manufacturer == nil)
        #expect(result?.model == nil)
        #expect(result?.hardwareVersion == nil)
        #expect(result?.softwareVersion == nil)
    }

    @Test func parseDeviceStringWithNameAndSoftwareOnly() {
        let input = "<<HKDevice: 0xdef>, name:Oura, software:2.14.0>"
        let result = DeviceStringParser.parse(input)

        #expect(result != nil)
        #expect(result?.name == "Oura")
        #expect(result?.manufacturer == nil)
        #expect(result?.model == nil)
        #expect(result?.hardwareVersion == nil)
        #expect(result?.softwareVersion == "2.14.0")
    }
}
