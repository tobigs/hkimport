//
//  DeviceStringParser.swift
//  HKImport
//
//  Parses the serialized HKDevice string from Apple Health export XML.
//

import Foundation

struct DeviceStringParser {
    struct ParsedDevice {
        let name: String?
        let manufacturer: String?
        let model: String?
        let hardwareVersion: String?
        let softwareVersion: String?
    }

    /// Parses strings like:
    /// `<<HKDevice: 0x6b879dfe0>, name:iPhone, manufacturer:Apple Inc., model:iPhone, hardware:iPhone16,2, software:18.3.2>`
    ///
    /// The format is: `<<HKDevice: 0xHEX>, key:value, key:value, ...>`
    /// Keys of interest: name, manufacturer, model, hardware, software.
    /// Returns nil for non-matching strings.
    static func parse(_ deviceString: String) -> ParsedDevice? {
        // Must start with "<<HKDevice:" and end with ">"
        guard deviceString.hasPrefix("<<HKDevice:"),
              deviceString.hasSuffix(">") else {
            return nil
        }

        // Find the closing ">" of the inner hex address portion: "<<HKDevice: 0x...>"
        // Then the key:value pairs follow after ", "
        guard let innerClose = deviceString.range(of: ">,", options: .literal,
                                                   range: deviceString.index(deviceString.startIndex, offsetBy: 11)..<deviceString.endIndex) else {
            return nil
        }

        // Extract the key:value portion (between first ">," and the trailing ">")
        let kvStart = innerClose.upperBound
        let kvEnd = deviceString.index(deviceString.endIndex, offsetBy: -1) // drop trailing ">"
        guard kvStart < kvEnd else { return nil }

        let kvString = String(deviceString[kvStart..<kvEnd])

        // Parse key:value pairs. Values can contain commas (e.g. "Apple Inc., model:iPhone")
        // Strategy: find all "key:" patterns and split on them.
        let knownKeys = ["name", "manufacturer", "model", "hardware", "software",
                         "UDIDeviceIdentifier", "creation date", "localIdentifier", "firmwareVersion"]

        var fields: [String: String] = [:]
        var remaining = kvString.trimmingCharacters(in: .whitespaces)

        while !remaining.isEmpty {
            // Find the next key at the current position
            var matchedKey: String?
            for key in knownKeys where remaining.hasPrefix("\(key):") {
                matchedKey = key
                break
            }

            guard let key = matchedKey else {
                // Skip unexpected content up to next ", " or end
                if let nextComma = remaining.range(of: ", ") {
                    remaining = String(remaining[nextComma.upperBound...])
                } else {
                    break
                }
                continue
            }

            // Remove "key:" prefix
            remaining = String(remaining.dropFirst(key.count + 1))

            // Find where this value ends: at the next ", knownKey:" boundary
            var valueEnd = remaining.endIndex
            for nextKey in knownKeys {
                let separator = ", \(nextKey):"
                if let range = remaining.range(of: separator) {
                    if range.lowerBound < valueEnd {
                        valueEnd = range.lowerBound
                    }
                }
            }

            let value = String(remaining[remaining.startIndex..<valueEnd])
            fields[key] = value

            if valueEnd == remaining.endIndex {
                break
            }
            // Advance past ", "
            remaining = String(remaining[valueEnd...].dropFirst(2))
        }

        return ParsedDevice(
            name: fields["name"],
            manufacturer: fields["manufacturer"],
            model: fields["model"],
            hardwareVersion: fields["hardware"],
            softwareVersion: fields["software"]
        )
    }
}
