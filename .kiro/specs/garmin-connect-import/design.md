# Design Document: Garmin Connect Import

## Architecture Overview

The Garmin Connect Import feature adds a parallel import pipeline to HKImport that reads Garmin data export JSON files and converts them to HealthKit samples. The architecture follows a parser-per-data-type pattern with a central coordinator that handles directory discovery, authorization, batching, and HealthKit persistence.

```
┌─────────────────────────────────────────────────────────┐
│                    ViewController                         │
│  ┌──────────┐  ┌──────────────────┐                     │
│  │  Start   │  │  Import Garmin   │                     │
│  └──────────┘  └──────────────────┘                     │
└────────┬────────────────┬───────────────────────────────┘
         │                │
         ▼                ▼
┌────────────────┐  ┌──────────────────────────────────────┐
│   Importer     │  │        GarminImporter                 │
│  (XML-based)   │  │  ┌────────────────────────────────┐  │
└────────────────┘  │  │  GarminDirectoryDiscovery       │  │
                    │  └────────────────────────────────┘  │
                    │  ┌────────────────────────────────┐  │
                    │  │  GarminTimestampParser          │  │
                    │  └────────────────────────────────┘  │
                    │  ┌────────────────────────────────┐  │
                    │  │  GarminDeviceFactory            │  │
                    │  └────────────────────────────────┘  │
                    │  ┌────────────────────────────────┐  │
                    │  │  Parsers:                       │  │
                    │  │  • UDSParser                    │  │
                    │  │  • SleepParser                  │  │
                    │  │  • HealthStatusParser           │  │
                    │  │  • VO2MaxParser                 │  │
                    │  │  • ActivityParser               │  │
                    │  │  • HydrationParser              │  │
                    │  └────────────────────────────────┘  │
                    │  ┌────────────────────────────────┐  │
                    │  │  GarminActivityTypeMapper       │  │
                    │  └────────────────────────────────┘  │
                    └──────────────────────────────────────┘
                                    │
                                    ▼
                    ┌──────────────────────────────────────┐
                    │         HKHealthStore.save            │
                    │       (existing infrastructure)       │
                    └──────────────────────────────────────┘
```

## Directory Structure

All new code resides in `HKImport/GarminConnect/`:

```
HKImport/GarminConnect/
├── GarminImporter.swift              # Coordinator: auth, discovery, orchestration, batching
├── GarminDirectoryDiscovery.swift    # Finds Garmin export directory
├── GarminTimestampParser.swift       # Timestamp parsing utilities
├── GarminDeviceFactory.swift         # Creates HKDevice + metadata helpers
├── GarminActivityTypeMapper.swift    # Garmin → HKWorkoutActivityType mapping
├── Models/
│   ├── GarminUDSRecord.swift         # Codable model for UDS JSON
│   ├── GarminSleepRecord.swift       # Codable model for sleep JSON
│   ├── GarminHealthStatusRecord.swift# Codable model for health status JSON
│   ├── GarminVO2MaxRecord.swift      # Codable model for VO2Max JSON
│   ├── GarminActivityRecord.swift    # Codable model for summarizedActivities JSON
│   └── GarminHydrationRecord.swift   # Codable model for hydration JSON
└── Parsers/
    ├── GarminParser.swift            # Protocol defining parser interface
    ├── UDSParser.swift               # UDS → HKQuantitySample
    ├── SleepParser.swift             # Sleep → HKCategorySample
    ├── HealthStatusParser.swift      # Health status → HKQuantitySample
    ├── VO2MaxParser.swift            # VO2Max → HKQuantitySample
    ├── ActivityParser.swift          # Activities → HKWorkout
    └── HydrationParser.swift         # Hydration → HKQuantitySample
```

## Components

### GarminImporter (Coordinator)

The central orchestrator that manages the full import lifecycle:

```swift
import HealthKit
import os.log

class GarminImporter {
    private let healthStore: HKHealthStore
    private let batchSize = 1000
    private var readCount = 0
    private var writeCount = 0

    weak var readCounterLabel: UILabel?
    weak var writeCounterLabel: UILabel?

    init() {
        self.healthStore = HKHealthStore()
    }

    /// Entry point: authorize → discover → analyze → import
    func startImport(completion: @escaping () -> Void) {
        requestAuthorization { [weak self] in
            guard let self = self else { return }
            guard let exportDir = GarminDirectoryDiscovery.findExportDirectory() else {
                os_log("Garmin export directory not found")
                return
            }
            self.runAnalysisPass(exportDirectory: exportDir)
            self.runImportPass(exportDirectory: exportDir, completion: completion)
        }
    }

    private func requestAuthorization(completion: @escaping () -> Void) { ... }
    private func runAnalysisPass(exportDirectory: URL) { ... }
    private func runImportPass(exportDirectory: URL, completion: @escaping () -> Void) { ... }
    private func saveBatch(_ samples: [HKSample], completion: @escaping () -> Void) { ... }
}
```

### GarminDirectoryDiscovery

Locates the Garmin export directory by searching for a UUID-named directory containing a `DI_CONNECT` subdirectory:

```swift
struct GarminDirectoryDiscovery {
    /// Searches Documents directory, then app bundle, for a Garmin export directory.
    /// A valid directory contains a DI_CONNECT subdirectory.
    static func findExportDirectory() -> URL? {
        if let docsDir = findInDocuments() { return docsDir }
        if let bundleDir = findInBundle() { return bundleDir }
        return nil
    }

    private static func findInDocuments() -> URL? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return searchForGarminExport(in: documentsURL)
    }

    private static func findInBundle() -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        return searchForGarminExport(in: resourceURL)
    }

    /// Searches for a subdirectory containing DI_CONNECT
    static func searchForGarminExport(in directory: URL) -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return nil }

        for item in contents {
            var isDir: ObjCBool = false
            let diConnect = item.appendingPathComponent("DI_CONNECT")
            if fm.fileExists(atPath: diConnect.path, isDirectory: &isDir), isDir.boolValue {
                return item
            }
        }
        return nil
    }
}
```

### GarminTimestampParser

Centralized timestamp parsing with four format strategies:

```swift
struct GarminTimestampParser {
    /// Parses "yyyy-MM-dd'T'HH:mm:ss.S" in UTC
    static func parseGMT(_ string: String) -> Date? { ... }

    /// Parses "yyyy-MM-dd'T'HH:mm:ss.S" in local timezone
    static func parseLocal(_ string: String) -> Date? { ... }

    /// Parses epoch milliseconds to Date
    static func parseEpochMillis(_ millis: Double) -> Date {
        return Date(timeIntervalSince1970: millis / 1000.0)
    }

    /// Parses "yyyy-MM-dd" calendar date
    static func parseCalendarDate(_ string: String) -> Date? { ... }

    // Shared formatters (thread-safe via static let)
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
```

### GarminDeviceFactory

Creates the shared HKDevice and metadata dictionaries:

```swift
struct GarminDeviceFactory {
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

    /// Builds metadata dictionary with standard Garmin keys
    static func metadata(
        uuid: String? = nil,
        calendarDate: String? = nil,
        userProfilePK: Int? = nil,
        additional: [String: Any]? = nil
    ) -> [String: Any] {
        var meta: [String: Any] = [:]
        if let uuid = uuid { meta["GarminConnectUUID"] = uuid }
        if let date = calendarDate { meta["GarminConnectCalendarDate"] = date }
        if let pk = userProfilePK { meta["GarminConnectUserProfilePK"] = pk }
        if let additional = additional {
            meta.merge(additional) { _, new in new }
        }
        return meta
    }
}
```

### GarminActivityTypeMapper

Maps Garmin activity type strings to HKWorkoutActivityType:

```swift
struct GarminActivityTypeMapper {
    private static let mapping: [String: HKWorkoutActivityType] = [
        "running": .running,
        "treadmill_running": .running,
        "trail_running": .running,
        "cycling": .cycling,
        "indoor_cycling": .cycling,
        "gravel_cycling": .cycling,
        "virtual_ride": .cycling,
        "swimming": .swimming,
        "open_water_swimming": .swimming,
        "lap_swimming": .swimming,
        "strength_training": .traditionalStrengthTraining,
        "indoor_cardio": .traditionalStrengthTraining,
        "walking": .walking,
        "hiking": .hiking,
        "elliptical": .elliptical,
        "yoga": .yoga
    ]

    /// Returns the mapped HKWorkoutActivityType, or .other for unknown types
    static func map(_ garminType: String) -> HKWorkoutActivityType {
        return mapping[garminType.lowercased()] ?? .other
    }
}
```

### Parser Protocol

```swift
protocol GarminParser {
    associatedtype RecordType: Decodable
    /// Parse JSON data into Codable records
    func decode(data: Data) throws -> [RecordType]
    /// Convert a single record into zero or more HKSamples
    func convert(record: RecordType) -> [HKSample]
}
```

## Data Models

### GarminUDSRecord

```swift
struct GarminUDSRecord: Decodable {
    let userProfilePK: Int
    let calendarDate: String
    let uuid: String?
    let totalSteps: Int?
    let totalDistanceMeters: Int?
    let activeKilocalories: Double?
    let bmrKilocalories: Double?
    let wellnessStartTimeLocal: String?
    let wellnessEndTimeLocal: String?
    let minAvgHeartRate: Int?
    let userFloorsAscendedGoal: Int?
    let floorsAscended: Double?  // derived from activity data if available
}
```

### GarminSleepRecord

```swift
struct GarminSleepRecord: Decodable {
    let sleepStartTimestampGMT: String
    let sleepEndTimestampGMT: String
    let calendarDate: String
    let deepSleepSeconds: Int
    let lightSleepSeconds: Int
    let remSleepSeconds: Int?  // may be absent in short sleep sessions
    let awakeSleepSeconds: Int
}
```

### GarminHealthStatusRecord

```swift
struct GarminHealthStatusRecord: Decodable {
    let calendarDate: String
    let createTimestampUTC: String
    let metrics: [GarminHealthMetric]
}

struct GarminHealthMetric: Decodable {
    let type: String       // "HRV", "HR", "SPO2", "RESPIRATION", "SKIN_TEMP_C"
    let value: Double?     // null when status is "UNKNOWN"
}
```

### GarminVO2MaxRecord

```swift
struct GarminVO2MaxRecord: Decodable {
    let userProfilePK: Int
    let calendarDate: String
    let updateTimestamp: String
    let sport: String
    let subSport: String?
    let vo2MaxValue: Double?
}
```

### GarminActivityRecord

```swift
struct GarminActivityWrapper: Decodable {
    let summarizedActivitiesExport: [GarminActivityRecord]
}

struct GarminActivityRecord: Decodable {
    let activityId: Int
    let name: String?
    let activityType: String
    let startTimeGmt: Double      // epoch milliseconds
    let duration: Double          // milliseconds
    let distance: Double?         // meters
    let calories: Double?         // kilocalories
}
```

### GarminHydrationRecord

```swift
struct GarminHydrationRecord: Decodable {
    let userProfilePK: Int
    let calendarDate: String
    let timestampLocal: String
    let hydrationSource: String?
    let valueInML: Double
    let uuid: GarminUUID?
}

struct GarminUUID: Decodable {
    let uuid: String
}
```

## Interfaces

### Parser Implementations

Each parser follows the same pattern: decode JSON → filter valid records → convert to HKSample:

**UDSParser** converts each UDS record into up to 6 samples (steps, distance, active cal, basal cal, resting HR, floors). Zero/missing values are skipped.

**SleepParser** converts each sleep record into up to 4 category samples (deep, core, REM, awake). Stages are distributed sequentially within the sleep window. Zero-duration stages are skipped.

**HealthStatusParser** converts each health status record into up to 4 samples (HRV, HR, SpO2, respiration). Null-value metrics are skipped. SpO2 values are divided by 100 to express as fraction.

**VO2MaxParser** converts each record into a single VO2Max sample with sport/subSport metadata.

**ActivityParser** converts each activity into an HKWorkout with mapped activity type, energy, distance, and metadata.

**HydrationParser** converts each record with valueInML > 0 into a DietaryWater sample (point-in-time).

### Import Flow

```
1. User taps "Import Garmin"
2. GarminImporter.startImport()
3. Request HealthKit authorization for all target types
4. GarminDirectoryDiscovery.findExportDirectory()
5. Analysis pass: each parser reads files, logs statistics
6. Import pass: each parser produces [HKSample]
7. Samples batched (max 1000) and saved via HKHealthStore.save
8. UI counters updated after each batch
```

## Error Handling

| Error Condition | Handling Strategy |
|---|---|
| Export directory not found | Log error, stop import |
| JSON decode failure for a file | Log warning, skip file, continue with others |
| Timestamp parse failure for a record | Log warning, skip record, continue |
| HealthKit authorization denied for a type | Skip samples of that type, continue others |
| Batch save failure | Log error, proceed with next batch |
| Zero/null values in optional fields | Skip that specific sample, continue |

All errors are logged via `os_log` and do not crash the app. The importer is resilient — individual record failures do not halt the overall import.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: UDS record parsing produces correct sample set

*For any* valid UDS record with non-zero field values, the UDS parser SHALL produce HKQuantitySamples with the correct HealthKit types (StepCount, DistanceWalkingRunning, ActiveEnergyBurned, BasalEnergyBurned, RestingHeartRate, FlightsClimbed), correct values (distance converted from meters to kilometers), and start/end dates matching the `wellnessStartTimeLocal` and `wellnessEndTimeLocal` fields. Records with zero or missing values for a given field SHALL produce no sample for that type.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.1, 4.3, 5.1, 5.2**

### Property 2: Health status metric parsing with value transformation

*For any* health status record containing metrics with non-null values, the Health Status parser SHALL produce the correct HKQuantitySample types (HeartRateVariabilitySDNN for "HRV", RespiratoryRate for "RESPIRATION", OxygenSaturation for "SPO2", RestingHeartRate for "HR") with SpO2 values divided by 100 to express as a fraction in [0.0, 1.0], and sample dates derived from the `createTimestampUTC` field. Metrics with null values SHALL produce no sample.

**Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 4.2**

### Property 3: Sleep stage distribution within sleep window

*For any* sleep record, the Sleep parser SHALL produce category samples whose total duration (sum of all stage seconds) fits within the sleep window defined by `sleepStartTimestampGMT` and `sleepEndTimestampGMT`. Each stage sample's start and end dates SHALL fall within the overall sleep window. Stages with zero seconds SHALL produce no sample.

**Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7**

### Property 4: VO2Max parsing preserves value and metadata

*For any* MetricsMaxMetData or ActivityVo2Max record with a non-null `vo2MaxValue`, the VO2Max parser SHALL produce an HKQuantitySample of type VO2Max with the exact numeric value in mL/(kg·min) units, sample date matching the `updateTimestamp` field, and metadata containing the `sport` and `subSport` fields.

**Validates: Requirements 8.1, 8.2, 8.3, 8.4**

### Property 5: Activity type mapping totality

*For any* string input to the activity type mapper, the function SHALL return a valid HKWorkoutActivityType. Known Garmin types (running, cycling, indoor_cycling, swimming, open_water_swimming, lap_swimming, strength_training, indoor_cardio, walking, hiking, elliptical, yoga) SHALL map to their defined HKWorkoutActivityType. All other strings SHALL map to `.other`.

**Validates: Requirements 9.5, 9.6, 17.1, 17.2, 17.3, 17.4, 17.5, 17.6, 17.7, 17.8, 17.9**

### Property 6: Activity record to workout conversion

*For any* valid summarizedActivities record, the Activity parser SHALL produce an HKWorkout where: the start date equals `Date(timeIntervalSince1970: startTimeGmt / 1000)`, the duration equals `duration / 1000` seconds, `totalEnergyBurned` matches the `calories` field in kilocalories, `totalDistance` equals `distance / 1000` in kilometers (when distance > 0), and metadata contains the original `activityType`, `activityId`, and `name` fields.

**Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.7**

### Property 7: Hydration record parsing

*For any* hydration record with `valueInML > 0`, the Hydration parser SHALL produce an HKQuantitySample of type DietaryWater with the value in milliliters, start date equal to end date (point-in-time from `timestampLocal`), and metadata containing `hydrationSource` and `uuid`. Records with `valueInML <= 0` SHALL produce no sample.

**Validates: Requirements 10.1, 10.2, 10.3, 10.4**

### Property 8: Source identification invariant

*For any* HKSample produced by any Garmin parser, the sample SHALL have its device set with name "Garmin Connect" and manufacturer "Garmin", and its metadata SHALL contain "GarminConnectUserProfilePK". When the source record contains a UUID, metadata SHALL contain "GarminConnectUUID". When the source record contains a calendarDate, metadata SHALL contain "GarminConnectCalendarDate".

**Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**

### Property 9: Timestamp parsing correctness

*For any* valid Garmin timestamp string in GMT format ("yyyy-MM-dd'T'HH:mm:ss.S"), parsing with UTC timezone and then formatting back SHALL produce the original string. *For any* epoch millisecond value, `parseEpochMillis(ms).timeIntervalSince1970 * 1000` SHALL equal the original value. *For any* valid calendar date string ("yyyy-MM-dd"), parsing and formatting back SHALL produce the original string.

**Validates: Requirements 16.1, 16.2, 16.3, 16.4**

### Property 10: Batch size invariant

*For any* collection of samples passed to the batch save mechanism, each individual save call SHALL contain at most 1000 samples. The total number of samples across all batches SHALL equal the input collection size.

**Validates: Requirements 15.1**
