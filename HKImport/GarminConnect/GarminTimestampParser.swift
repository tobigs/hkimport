//
//  GarminTimestampParser.swift
//  HKImport
//
//  Centralized timestamp parsing for Garmin Connect export data.
//  Supports four format strategies: GMT, local, epoch millis, and calendar date.
//

import Foundation
import os.log

struct GarminTimestampParser {

    // MARK: - Public Parsing Methods

    /// Parses "yyyy-MM-dd'T'HH:mm:ss.S" in UTC timezone.
    /// Used for GMT timestamps like sleepStartTimestampGMT, sleepEndTimestampGMT, startTimeGmt.
    static func parseGMT(_ string: String) -> Date? {
        return gmtFormatter.date(from: string)
    }

    /// Parses "yyyy-MM-dd'T'HH:mm:ss.S" in the device's local timezone.
    /// Used for local timestamps like wellnessStartTimeLocal, wellnessEndTimeLocal, timestampLocal.
    static func parseLocal(_ string: String) -> Date? {
        return localFormatter.date(from: string)
    }

    /// Parses epoch milliseconds (Double) to Date.
    /// Used for activity startTimeGmt fields (e.g., 1778566720000.0).
    static func parseEpochMillis(_ millis: Double) -> Date {
        return Date(timeIntervalSince1970: millis / 1000.0)
    }

    /// Parses "yyyy-MM-dd" calendar date string in UTC.
    /// Used for calendarDate fields across all Garmin data types.
    static func parseCalendarDate(_ string: String) -> Date? {
        return calendarDateFormatter.date(from: string)
    }

    // MARK: - Shared Formatters (thread-safe via static let)

    private static let gmtFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.S"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let localFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.S"
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let calendarDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
