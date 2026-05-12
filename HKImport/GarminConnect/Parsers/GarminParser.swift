//
//  GarminParser.swift
//  HKImport
//
//  Protocol defining the interface for all Garmin data parsers.
//

import HealthKit

/// Protocol that all Garmin data parsers conform to.
/// Each parser handles a specific Garmin data type (UDS, Sleep, VO2Max, etc.)
/// and converts records into HealthKit samples.
protocol GarminParser {
    associatedtype RecordType: Decodable

    /// Parse JSON data into an array of Codable records.
    /// - Parameter data: Raw JSON data from a Garmin export file.
    /// - Returns: Array of decoded records.
    /// - Throws: DecodingError if the JSON cannot be parsed.
    func decode(data: Data) throws -> [RecordType]

    /// Convert a single Garmin record into zero or more HealthKit samples.
    /// Returns an empty array if the record has no valid data to import.
    /// - Parameter record: A decoded Garmin record.
    /// - Returns: Array of HKSample instances (may be empty).
    func convert(record: RecordType) -> [HKSample]
}
