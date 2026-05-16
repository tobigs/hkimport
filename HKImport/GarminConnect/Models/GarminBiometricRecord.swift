import Foundation

struct GarminBiometricRecord: Decodable {
    let version: Int64?
    let metaData: GarminBiometricMetadata?
    let weight: GarminWeightEntry?
}

struct GarminBiometricMetadata: Decodable {
    let userProfilePK: Int?
    let calendarDate: String?
}

struct GarminWeightEntry: Decodable {
    let weight: Double
    let sourceType: String?
    let timestampGMT: String?
}
