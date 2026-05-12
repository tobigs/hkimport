# Requirements Document

## Introduction

This feature adds a Garmin Connect data import capability to HKImport. The importer reads the full Garmin data export directory structure (JSON files), maps supported data types to HealthKit equivalents, and saves them to the Health store. The implementation is kept separate from the existing XML-based import flow to facilitate upstream contribution. All imported samples use "Garmin Connect" as the source name with original Garmin metadata preserved in custom metadata keys. No deduplication logic is included — a consistent provider/source ID is used instead.

## Glossary

- **Garmin_Importer**: The new import subsystem responsible for reading Garmin Connect export JSON files and converting them to HealthKit samples
- **UDS_Parser**: The component that parses User Daily Summary (UDS) JSON files from the Garmin export
- **Sleep_Parser**: The component that parses sleep data JSON files from the Garmin export
- **Health_Status_Parser**: The component that parses health status data JSON files containing nightly HRV, resting HR, SpO2, and respiration metrics
- **VO2Max_Parser**: The component that parses MetricsMaxMetData and ActivityVo2Max JSON files from the Garmin export
- **Activity_Parser**: The component that parses summarizedActivities JSON files from the Garmin export
- **Hydration_Parser**: The component that parses HydrationLogFile JSON files from the Garmin export
- **HKImport_App**: The existing iOS application that imports Apple Health export XML data
- **Garmin_Export_Directory**: The directory structure produced by a Garmin Connect data export, containing subdirectories like DI_CONNECT/DI-Connect-Aggregator, DI-Connect-Fitness, DI-Connect-Wellness, and DI-Connect-Metrics
- **Source_Identifier**: The combination of HKDevice name ("Garmin Connect") and custom metadata keys used to identify Garmin-imported samples in HealthKit

## Requirements

### Requirement 1: Garmin Import UI Entry Point

**User Story:** As a user, I want a separate "Import Garmin" button in the app so that I can import Garmin Connect data independently from the existing Apple Health XML import.

#### Acceptance Criteria

1. THE HKImport_App SHALL display an "Import Garmin" button on the main screen alongside the existing "Start" button.
2. WHEN the user taps the "Import Garmin" button, THE Garmin_Importer SHALL begin the import process using the Garmin_Export_Directory.
3. WHILE the Garmin_Importer is processing data, THE HKImport_App SHALL display a read counter and write counter showing import progress.

### Requirement 2: Garmin Export Directory Discovery

**User Story:** As a user, I want the app to find my Garmin export data from the Documents directory or app bundle so that I can import without manual file management.

#### Acceptance Criteria

1. WHEN the import starts, THE Garmin_Importer SHALL search the app Documents directory for a directory matching the Garmin export UUID structure (containing a DI_CONNECT subdirectory).
2. IF no Garmin_Export_Directory is found in the Documents directory, THEN THE Garmin_Importer SHALL search the app bundle for a bundled Garmin export directory.
3. IF no Garmin_Export_Directory is found in either location, THEN THE Garmin_Importer SHALL log an error message and stop the import process.

### Requirement 3: UDS Data Import (Daily Summaries)

**User Story:** As a user, I want my Garmin daily summary data (steps, distance, calories, resting HR, SpO2, respiration, floors) imported into HealthKit so that I have a complete health history.

#### Acceptance Criteria

1. WHEN a UDS JSON file is parsed, THE UDS_Parser SHALL extract the `totalSteps` field and create an HKQuantitySample of type StepCount with the value in count units.
2. WHEN a UDS JSON file is parsed, THE UDS_Parser SHALL extract the `totalDistanceMeters` field and create an HKQuantitySample of type DistanceWalkingRunning with the value converted to kilometers.
3. WHEN a UDS JSON file is parsed, THE UDS_Parser SHALL extract the `activeKilocalories` field and create an HKQuantitySample of type ActiveEnergyBurned with the value in kilocalorie units.
4. WHEN a UDS JSON file is parsed, THE UDS_Parser SHALL extract the `bmrKilocalories` field and create an HKQuantitySample of type BasalEnergyBurned with the value in kilocalorie units.
5. WHEN a UDS JSON file is parsed, THE UDS_Parser SHALL use `wellnessStartTimeLocal` as the sample start date and `wellnessEndTimeLocal` as the sample end date.
6. IF the `totalSteps` field is zero or missing, THEN THE UDS_Parser SHALL skip creation of the StepCount sample for that record.
7. IF the `totalDistanceMeters` field is zero or missing, THEN THE UDS_Parser SHALL skip creation of the DistanceWalkingRunning sample for that record.

### Requirement 4: UDS Resting Heart Rate and SpO2 Import

**User Story:** As a user, I want my Garmin resting heart rate and SpO2 data imported so that I can track cardiovascular health trends.

#### Acceptance Criteria

1. WHEN a UDS record contains `minAvgHeartRate` greater than zero, THE UDS_Parser SHALL create an HKQuantitySample of type RestingHeartRate using the `minAvgHeartRate` value in count/min units.
2. WHEN a UDS record contains SpO2 data from the `includesAllDayPulseOx` or `includesSleepPulseOx` flags being true, THE Health_Status_Parser SHALL extract SpO2 values and create HKQuantitySamples of type OxygenSaturation with values expressed as a fraction (0.0–1.0).
3. THE UDS_Parser SHALL set the start and end date for RestingHeartRate samples to the calendar date of the UDS record (full day span from `wellnessStartTimeLocal` to `wellnessEndTimeLocal`).

### Requirement 5: UDS Floors Climbed Import

**User Story:** As a user, I want my Garmin floors climbed data imported into HealthKit so that I can see elevation activity history.

#### Acceptance Criteria

1. WHEN a UDS record contains floor data (derived from the `userFloorsAscendedGoal` field context and activity data), THE UDS_Parser SHALL create an HKQuantitySample of type FlightsClimbed with the value in count units.
2. IF the floors climbed value is zero or unavailable, THEN THE UDS_Parser SHALL skip creation of the FlightsClimbed sample for that record.

### Requirement 6: Sleep Data Import

**User Story:** As a user, I want my Garmin sleep data with sleep stages imported into HealthKit so that I can analyze my sleep patterns.

#### Acceptance Criteria

1. WHEN a sleep data JSON file is parsed, THE Sleep_Parser SHALL create an HKCategorySample of type SleepAnalysis with value AsleepDeep using the `deepSleepSeconds` duration.
2. WHEN a sleep data JSON file is parsed, THE Sleep_Parser SHALL create an HKCategorySample of type SleepAnalysis with value AsleepCore using the `lightSleepSeconds` duration.
3. WHEN a sleep data JSON file is parsed, THE Sleep_Parser SHALL create an HKCategorySample of type SleepAnalysis with value AsleepREM using the `remSleepSeconds` duration.
4. WHEN a sleep data JSON file is parsed, THE Sleep_Parser SHALL create an HKCategorySample of type SleepAnalysis with value Awake using the `awakeSleepSeconds` duration.
5. THE Sleep_Parser SHALL use `sleepStartTimestampGMT` as the overall sleep session start and `sleepEndTimestampGMT` as the overall sleep session end, distributing stage durations sequentially within that window.
6. IF `deepSleepSeconds` is zero, THEN THE Sleep_Parser SHALL skip creation of the AsleepDeep sample for that night.
7. IF `remSleepSeconds` is zero, THEN THE Sleep_Parser SHALL skip creation of the AsleepREM sample for that night.

### Requirement 7: Health Status Data Import (Nightly HRV, Respiration)

**User Story:** As a user, I want my Garmin nightly health status metrics (HRV, respiration rate) imported into HealthKit so that I can track recovery trends.

#### Acceptance Criteria

1. WHEN a health status record contains a metric of type "HRV" with a non-null value, THE Health_Status_Parser SHALL create an HKQuantitySample of type HeartRateVariabilitySDNN with the value in millisecond units.
2. WHEN a health status record contains a metric of type "RESPIRATION" with a non-null value, THE Health_Status_Parser SHALL create an HKQuantitySample of type RespiratoryRate with the value in count/min units.
3. WHEN a health status record contains a metric of type "SPO2" with a non-null value, THE Health_Status_Parser SHALL create an HKQuantitySample of type OxygenSaturation with the value divided by 100 (expressed as a fraction 0.0–1.0).
4. WHEN a health status record contains a metric of type "HR" with a non-null value, THE Health_Status_Parser SHALL create an HKQuantitySample of type RestingHeartRate with the value in count/min units.
5. THE Health_Status_Parser SHALL use the `calendarDate` field to derive the sample timestamp, setting the start and end date to the creation timestamp of the record.

### Requirement 8: VO2Max Data Import

**User Story:** As a user, I want my Garmin VO2Max measurements imported into HealthKit so that I can track cardiorespiratory fitness over time.

#### Acceptance Criteria

1. WHEN a MetricsMaxMetData record contains a `vo2MaxValue` field with a non-null value, THE VO2Max_Parser SHALL create an HKQuantitySample of type VO2Max with the value in mL/kg·min units.
2. WHEN an ActivityVo2Max record contains a `vo2MaxValue` field with a non-null value, THE VO2Max_Parser SHALL create an HKQuantitySample of type VO2Max with the value in mL/kg·min units.
3. THE VO2Max_Parser SHALL use the `updateTimestamp` (MetricsMaxMetData) or `timestampGmt` (ActivityVo2Max) as the sample date.
4. THE VO2Max_Parser SHALL store the `sport` and `subSport` fields as custom metadata on the VO2Max sample.

### Requirement 9: Summarized Activities (Workout) Import

**User Story:** As a user, I want my Garmin activities imported as HealthKit workouts so that I can see my complete exercise history.

#### Acceptance Criteria

1. WHEN a summarizedActivities record is parsed, THE Activity_Parser SHALL create an HKWorkout with the activity type mapped from the Garmin `activityType` field to the corresponding HKWorkoutActivityType.
2. THE Activity_Parser SHALL set the workout start date from `startTimeGmt` (converted from epoch milliseconds) and calculate the end date by adding `duration` (in milliseconds) to the start date.
3. THE Activity_Parser SHALL set `totalEnergyBurned` from the `calories` field in kilocalorie units.
4. THE Activity_Parser SHALL set `totalDistance` from the `distance` field converted from meters to kilometers when the distance value is greater than zero.
5. THE Activity_Parser SHALL map Garmin activity types to HKWorkoutActivityType using a defined mapping table (e.g., "running" → .running, "cycling" → .cycling, "indoor_cycling" → .cycling, "strength_training" → .traditionalStrengthTraining, "swimming" → .swimming).
6. IF a Garmin activity type has no defined mapping, THEN THE Activity_Parser SHALL use HKWorkoutActivityType.other for that workout.
7. THE Activity_Parser SHALL store the original Garmin `activityType`, `activityId`, and `name` fields as custom metadata on the workout.

### Requirement 10: Hydration Data Import

**User Story:** As a user, I want my Garmin hydration logs imported into HealthKit so that I can track water intake history.

#### Acceptance Criteria

1. WHEN a HydrationLogFile record contains a `valueInML` greater than zero, THE Hydration_Parser SHALL create an HKQuantitySample of type DietaryWater with the value in milliliter units.
2. THE Hydration_Parser SHALL use the `timestampLocal` field as the sample start date and set the end date equal to the start date (point-in-time sample).
3. IF the `valueInML` field is zero or negative, THEN THE Hydration_Parser SHALL skip creation of the DietaryWater sample for that record.
4. THE Hydration_Parser SHALL store the `hydrationSource` and `uuid` fields as custom metadata on the sample.

### Requirement 11: Source Identification and Metadata

**User Story:** As a user, I want all Garmin-imported samples clearly identified with a consistent source so that I can distinguish them from other data sources in HealthKit.

#### Acceptance Criteria

1. THE Garmin_Importer SHALL set the HKDevice name to "Garmin Connect" for all imported samples.
2. THE Garmin_Importer SHALL set the HKDevice manufacturer to "Garmin" for all imported samples.
3. THE Garmin_Importer SHALL store the original Garmin record UUID (when available) in a metadata key named "GarminConnectUUID".
4. THE Garmin_Importer SHALL store the Garmin `calendarDate` in a metadata key named "GarminConnectCalendarDate" for all samples where a calendar date is present in the source data.
5. THE Garmin_Importer SHALL store the Garmin `userProfilePK` in a metadata key named "GarminConnectUserProfilePK" for all samples.

### Requirement 12: Data Analysis Before Import

**User Story:** As a user, I want the importer to analyze each data type before importing so that I can verify the data looks correct and understand what will be imported.

#### Acceptance Criteria

1. WHEN the import process begins, THE Garmin_Importer SHALL perform a data analysis pass for each data type before writing any samples to HealthKit.
2. THE Garmin_Importer SHALL log the total record count, date range, and sample statistics (min/max/average values) for each data type during the analysis pass.
3. WHEN the analysis pass completes, THE Garmin_Importer SHALL proceed to the import pass and write all valid samples to HealthKit.

### Requirement 13: Code Separation for Upstream Contribution

**User Story:** As a developer, I want the Garmin import code kept separate from existing code so that it can be contributed upstream as an independent feature.

#### Acceptance Criteria

1. THE Garmin_Importer SHALL be implemented in a separate directory (HKImport/GarminConnect/) from the existing import code.
2. THE Garmin_Importer SHALL define its own data model types independent of the existing HealthRecord class.
3. THE Garmin_Importer SHALL reuse the existing HealthKit save infrastructure (HKHealthStore.save) for writing samples to the Health store.
4. THE Garmin_Importer SHALL request HealthKit authorization for all sample types it intends to write, using the same authorization pattern as the existing Importer class.

### Requirement 14: HealthKit Authorization

**User Story:** As a user, I want the app to request permission for all Garmin data types before importing so that the import completes without authorization failures.

#### Acceptance Criteria

1. WHEN the user taps "Import Garmin", THE Garmin_Importer SHALL request HealthKit write authorization for all sample types that the Garmin import produces (StepCount, DistanceWalkingRunning, ActiveEnergyBurned, BasalEnergyBurned, RestingHeartRate, OxygenSaturation, RespiratoryRate, FlightsClimbed, HeartRateVariabilitySDNN, VO2Max, DietaryWater, SleepAnalysis, and HKWorkout).
2. IF HealthKit authorization is denied for a specific type, THEN THE Garmin_Importer SHALL skip samples of that type and continue importing other authorized types.
3. WHEN authorization is granted, THE Garmin_Importer SHALL proceed with the data analysis and import passes.

### Requirement 15: Batch Saving

**User Story:** As a user, I want the import to handle large datasets reliably so that all my historical Garmin data is imported without failures.

#### Acceptance Criteria

1. THE Garmin_Importer SHALL save samples to HealthKit in batches of no more than 1000 samples per save operation.
2. IF a batch save fails, THEN THE Garmin_Importer SHALL log the error and proceed with the next batch.
3. THE Garmin_Importer SHALL update the write counter on the main screen after each successful batch save.

### Requirement 16: Timestamp Parsing

**User Story:** As a developer, I want consistent timestamp parsing across all Garmin data types so that samples have accurate dates in HealthKit.

#### Acceptance Criteria

1. THE Garmin_Importer SHALL parse Garmin GMT timestamps in the format "yyyy-MM-dd'T'HH:mm:ss.S" using the UTC timezone.
2. THE Garmin_Importer SHALL parse Garmin local timestamps in the format "yyyy-MM-dd'T'HH:mm:ss.S" using the device local timezone.
3. THE Garmin_Importer SHALL parse Garmin epoch timestamps (milliseconds since 1970-01-01) by dividing by 1000 and creating a Date from the TimeInterval.
4. THE Garmin_Importer SHALL parse Garmin calendar date strings in the format "yyyy-MM-dd".
5. IF a timestamp cannot be parsed, THEN THE Garmin_Importer SHALL skip the record and log a warning.

### Requirement 17: Garmin Activity Type Mapping

**User Story:** As a developer, I want a comprehensive mapping from Garmin activity types to HealthKit workout activity types so that workouts are categorized correctly.

#### Acceptance Criteria

1. THE Activity_Parser SHALL map "running" to HKWorkoutActivityType.running.
2. THE Activity_Parser SHALL map "cycling" and "indoor_cycling" to HKWorkoutActivityType.cycling.
3. THE Activity_Parser SHALL map "swimming" and "open_water_swimming" and "lap_swimming" to HKWorkoutActivityType.swimming.
4. THE Activity_Parser SHALL map "strength_training" and "indoor_cardio" to HKWorkoutActivityType.traditionalStrengthTraining.
5. THE Activity_Parser SHALL map "walking" to HKWorkoutActivityType.walking.
6. THE Activity_Parser SHALL map "hiking" to HKWorkoutActivityType.hiking.
7. THE Activity_Parser SHALL map "elliptical" to HKWorkoutActivityType.elliptical.
8. THE Activity_Parser SHALL map "yoga" to HKWorkoutActivityType.yoga.
9. THE Activity_Parser SHALL map unmapped Garmin activity types to HKWorkoutActivityType.other.
