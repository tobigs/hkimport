# Implementation Plan: Garmin Connect Import

## Overview

Implement a parallel Garmin Connect data import pipeline for HKImport. The implementation lives entirely in `HKImport/GarminConnect/` and follows a parser-per-data-type architecture with a central coordinator. Each parser reads Garmin export JSON files, converts records to HealthKit samples, and the coordinator handles authorization, batching, and persistence.

## Tasks

- [x] 1. Set up project structure and shared infrastructure
  - [x] 1.1 Create GarminConnect directory structure and shared utilities
    - Create `HKImport/GarminConnect/` directory with `Models/` and `Parsers/` subdirectories
    - Implement `GarminTimestampParser.swift` with four parsing strategies (GMT, local, epoch millis, calendar date)
    - Implement `GarminDeviceFactory.swift` with shared HKDevice and metadata builder
    - Implement `GarminActivityTypeMapper.swift` with the full Garmin → HKWorkoutActivityType mapping table
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 16.1, 16.2, 16.3, 16.4, 17.1–17.9_

  - [x] 1.2 Create GarminParser protocol and GarminDirectoryDiscovery
    - Implement `Parsers/GarminParser.swift` protocol with `decode(data:)` and `convert(record:)` methods
    - Implement `GarminDirectoryDiscovery.swift` that searches Documents then bundle for a directory containing `DI_CONNECT`
    - _Requirements: 2.1, 2.2, 2.3, 13.1, 13.2_

- [x] 2. Implement data models
  - [x] 2.1 Create Codable models for all Garmin data types
    - Implement `Models/GarminUDSRecord.swift` with all UDS fields (totalSteps, totalDistanceMeters, activeKilocalories, bmrKilocalories, minAvgHeartRate, floorsAscended, wellnessStartTimeLocal, wellnessEndTimeLocal, etc.)
    - Implement `Models/GarminSleepRecord.swift` with sleep stage durations and timestamps
    - Implement `Models/GarminHealthStatusRecord.swift` with metrics array (type + value)
    - Implement `Models/GarminVO2MaxRecord.swift` with vo2MaxValue, sport, subSport, updateTimestamp
    - Implement `Models/GarminActivityRecord.swift` with GarminActivityWrapper and activity fields
    - Implement `Models/GarminHydrationRecord.swift` with valueInML, timestampLocal, hydrationSource, uuid
    - _Requirements: 3.1–3.7, 6.1–6.7, 7.1–7.5, 8.1–8.4, 9.1–9.7, 10.1–10.4_

- [x] 3. Implement parsers (quantity samples)
  - [x] 3.1 Implement UDSParser
    - Implement `Parsers/UDSParser.swift` conforming to GarminParser
    - Parse UDS JSON arrays, produce up to 6 HKQuantitySamples per record (StepCount, DistanceWalkingRunning, ActiveEnergyBurned, BasalEnergyBurned, RestingHeartRate, FlightsClimbed)
    - Convert distance from meters to kilometers
    - Skip samples when values are zero or missing
    - Use wellnessStartTimeLocal/wellnessEndTimeLocal for sample dates
    - Attach device and metadata via GarminDeviceFactory
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.1, 4.3, 5.1, 5.2, 11.1–11.5_

  - [x]* 3.2 Write property test for UDSParser
    - **Property 1: UDS record parsing produces correct sample set**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.1, 4.3, 5.1, 5.2**

  - [x] 3.3 Implement HealthStatusParser
    - Implement `Parsers/HealthStatusParser.swift` conforming to GarminParser
    - Parse health status JSON, produce HKQuantitySamples for HRV (ms), HR (count/min), SpO2 (fraction 0–1), Respiration (count/min)
    - Divide SpO2 values by 100 to express as fraction
    - Skip metrics with null values
    - Use createTimestampUTC for sample dates
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 4.2_

  - [x]* 3.4 Write property test for HealthStatusParser
    - **Property 2: Health status metric parsing with value transformation**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 4.2**

  - [x] 3.5 Implement VO2MaxParser
    - Implement `Parsers/VO2MaxParser.swift` conforming to GarminParser
    - Parse MetricsMaxMetData and ActivityVo2Max JSON, produce HKQuantitySample of type VO2Max in mL/(kg·min)
    - Store sport and subSport as custom metadata
    - Use updateTimestamp or timestampGmt for sample date
    - Skip records with null vo2MaxValue
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [x]* 3.6 Write property test for VO2MaxParser
    - **Property 4: VO2Max parsing preserves value and metadata**
    - **Validates: Requirements 8.1, 8.2, 8.3, 8.4**

  - [x] 3.7 Implement HydrationParser
    - Implement `Parsers/HydrationParser.swift` conforming to GarminParser
    - Parse HydrationLogFile JSON, produce HKQuantitySample of type DietaryWater in milliliters
    - Set start date = end date (point-in-time) from timestampLocal
    - Skip records with valueInML <= 0
    - Store hydrationSource and uuid as metadata
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x]* 3.8 Write property test for HydrationParser
    - **Property 7: Hydration record parsing**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4**

- [x] 4. Implement parsers (category samples and workouts)
  - [x] 4.1 Implement SleepParser
    - Implement `Parsers/SleepParser.swift` conforming to GarminParser
    - Parse sleep JSON, produce HKCategorySamples for AsleepDeep, AsleepCore, AsleepREM, Awake
    - Distribute stage durations sequentially within the sleep window (sleepStartTimestampGMT to sleepEndTimestampGMT)
    - Skip stages with zero seconds
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [x]* 4.2 Write property test for SleepParser
    - **Property 3: Sleep stage distribution within sleep window**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7**

  - [x] 4.3 Implement ActivityParser
    - Implement `Parsers/ActivityParser.swift` conforming to GarminParser
    - Parse summarizedActivities JSON (via GarminActivityWrapper), produce HKWorkout per record
    - Map activity type via GarminActivityTypeMapper
    - Set start from epoch millis, calculate end from duration
    - Set totalEnergyBurned (kcal) and totalDistance (meters → km, when > 0)
    - Store activityType, activityId, name as custom metadata
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

  - [x]* 4.4 Write property test for ActivityParser
    - **Property 6: Activity record to workout conversion**
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7**

- [x] 5. Checkpoint
  - Ensure all parsers compile and tests pass, ask the user if questions arise.

- [x] 6. Implement GarminImporter coordinator
  - [x] 6.1 Implement GarminImporter with authorization and orchestration
    - Implement `GarminImporter.swift` as the central coordinator
    - Request HealthKit write authorization for all 13 sample types (StepCount, DistanceWalkingRunning, ActiveEnergyBurned, BasalEnergyBurned, RestingHeartRate, OxygenSaturation, RespiratoryRate, FlightsClimbed, HeartRateVariabilitySDNN, VO2Max, DietaryWater, SleepAnalysis, HKWorkout)
    - Skip samples of denied types, continue importing authorized types
    - Implement analysis pass: log record count, date range, min/max/average per data type
    - Implement import pass: invoke each parser, collect all HKSamples
    - _Requirements: 12.1, 12.2, 12.3, 13.3, 13.4, 14.1, 14.2, 14.3_

  - [x] 6.2 Implement batch saving with progress updates
    - Batch samples into groups of max 1000 for HKHealthStore.save
    - Log errors on batch failure, proceed with next batch
    - Update readCounterLabel and writeCounterLabel on main thread after each batch
    - _Requirements: 15.1, 15.2, 15.3_

  - [x]* 6.3 Write property test for batch size invariant
    - **Property 10: Batch size invariant**
    - **Validates: Requirements 15.1**

- [x] 7. Wire up UI and integrate
  - [x] 7.1 Add "Import Garmin" button to ViewController
    - Add an IBOutlet for a new "Import Garmin" UIButton in ViewController.swift
    - Add an IBAction that instantiates GarminImporter and calls startImport()
    - Wire readCounter and writeCounter labels to the GarminImporter
    - Follow the same pattern as the existing `start(_:)` action
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 7.2 Add new files to Xcode project
    - Ensure all new Swift files in HKImport/GarminConnect/ are added to the Xcode project target
    - Verify the project builds successfully with all new files included
    - _Requirements: 13.1_

- [x] 8. Additional property tests
  - [x]* 8.1 Write property test for activity type mapping totality
    - **Property 5: Activity type mapping totality**
    - **Validates: Requirements 9.5, 9.6, 17.1–17.9**

  - [x]* 8.2 Write property test for timestamp parsing correctness
    - **Property 9: Timestamp parsing correctness**
    - **Validates: Requirements 16.1, 16.2, 16.3, 16.4**

  - [x]* 8.3 Write property test for source identification invariant
    - **Property 8: Source identification invariant**
    - **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**

- [x] 9. Final checkpoint
  - Ensure all tests pass and the project builds cleanly, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- All new code lives in `HKImport/GarminConnect/` to keep it separate for upstream contribution
- New files must be added to the Xcode project (not SPM) — task 7.2 covers this
- The existing `Importer.swift` and `ViewController.swift` demonstrate the patterns to follow for HealthKit save and UI wiring

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["3.1", "3.3", "3.5", "3.7", "4.1", "4.3"] },
    { "id": 3, "tasks": ["3.2", "3.4", "3.6", "3.8", "4.2", "4.4"] },
    { "id": 4, "tasks": ["6.1"] },
    { "id": 5, "tasks": ["6.2"] },
    { "id": 6, "tasks": ["6.3", "7.1"] },
    { "id": 7, "tasks": ["7.2", "8.1", "8.2", "8.3"] }
  ]
}
```
