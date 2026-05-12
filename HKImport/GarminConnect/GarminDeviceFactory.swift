//
//  GarminDeviceFactory.swift
//  HKImport
//
//  Creates the shared HKDevice and metadata dictionaries for all Garmin-imported samples.
//  All samples use "Garmin Connect" as the source with "Garmin" as manufacturer.
//

import HealthKit

struct GarminDeviceFactory {

    /// Shared HKDevice instance for all Garmin-imported samples.
    static let device = HKDevice(
        name: "Garmin Connect",
        manufacturer: "Garmin",
        model: nil,
        hardwareVersion: nil,
        firmwareVersion: nil,
        softwareVersion: nil,
        localIdentifier: nil,
        udiDeviceIdentifier: nil
    )

    /// Builds a metadata dictionary with standard Garmin keys.
    ///
    /// - Parameters:
    ///   - uuid: The original Garmin record UUID (stored as "GarminConnectUUID").
    ///   - calendarDate: The Garmin calendarDate string (stored as "GarminConnectCalendarDate").
    ///   - userProfilePK: The Garmin userProfilePK (stored as "GarminConnectUserProfilePK").
    ///   - additional: Any extra metadata key-value pairs to merge in.
    /// - Returns: A metadata dictionary suitable for HKSample creation.
    static func metadata(
        uuid: String? = nil,
        calendarDate: String? = nil,
        userProfilePK: Int? = nil,
        additional: [String: Any]? = nil
    ) -> [String: Any] {
        var meta: [String: Any] = [:]
        if let uuid = uuid {
            meta["GarminConnectUUID"] = uuid
        }
        if let date = calendarDate {
            meta["GarminConnectCalendarDate"] = date
        }
        if let pk = userProfilePK {
            meta["GarminConnectUserProfilePK"] = pk
        }
        if let additional = additional {
            meta.merge(additional) { _, new in new }
        }
        return meta
    }
}
