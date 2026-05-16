//
//  GarminImporter.swift
//  HKImport
//
//  Central coordinator for the Garmin Connect import pipeline.
//  Handles HealthKit authorization, directory discovery, analysis pass,
//  and import pass. Delegates parsing to individual GarminParser implementations.
//

import UIKit
import HealthKit
import os.log

class GarminImporter {

    // MARK: - Properties

    private let healthStore: HKHealthStore
    private let batchSize = 1000
    private var readCount = 0
    private var writeCount = 0

    weak var readCounterLabel: UILabel?
    weak var writeCounterLabel: UILabel?

    private static let log = OSLog(subsystem: "com.hkimport", category: "GarminImporter")

    /// All HealthKit sample types that the Garmin import produces.
    private static let garminSampleTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        // Quantity types
        if let t = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .vo2Max) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .dietaryWater) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) { types.insert(t) }
        // Category types
        if let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(t) }
        // Workout type
        types.insert(HKObjectType.workoutType())
        return types
    }()

    // MARK: - Initialization

    init() {
        self.healthStore = HKHealthStore()
    }

    // MARK: - Public Entry Point

    /// Entry point: authorize → discover → analyze → import
    func startImport(completion: @escaping () -> Void) {
        requestAuthorization { [weak self] in
            guard let self = self else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                guard let exportDir = GarminDirectoryDiscovery.findExportDirectory() else {
                    os_log("Garmin export directory not found — aborting import",
                           log: GarminImporter.log, type: .error)
                    DispatchQueue.main.async { completion() }
                    return
                }

                os_log("Found Garmin export directory: %{public}@",
                       log: GarminImporter.log, type: .info, exportDir.path)

                self.runAnalysisPass(exportDirectory: exportDir)
                self.runImportPass(exportDirectory: exportDir, completion: completion)
            }
        }
    }

    // MARK: - Authorization

    /// Request HealthKit write authorization for all 13 Garmin sample types.
    private func requestAuthorization(completion: @escaping () -> Void) {
        healthStore.requestAuthorization(
            toShare: GarminImporter.garminSampleTypes,
            read: nil
        ) { success, error in
            if let error = error {
                os_log("HealthKit authorization error: %{public}@",
                       log: GarminImporter.log, type: .error, error.localizedDescription)
            }
            // Proceed regardless — we'll check per-type authorization when saving
            completion()
        }
    }

    // MARK: - Analysis Pass

    /// Iterate all Garmin export files, decode records, and log statistics per data type.
    private func runAnalysisPass(exportDirectory: URL) {
        os_log("=== Garmin Import: Analysis Pass ===", log: GarminImporter.log, type: .info)

        let diConnect = exportDirectory.appendingPathComponent("DI_CONNECT")

        // UDS files
        let udsFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Aggregator"),
                                 prefix: "UDSFile_", extension: "json")
        analyzeUDS(files: udsFiles)

        // Hydration files
        let hydrationFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Aggregator"),
                                       prefix: "HydrationLogFile_", extension: "json")
        analyzeHydration(files: hydrationFiles)

        // Sleep files
        let sleepFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Wellness"),
                                   suffix: "_sleepData.json")
        analyzeSleep(files: sleepFiles)

        // Health status files
        let healthStatusFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Wellness"),
                                          suffix: "_healthStatusData.json")
        analyzeHealthStatus(files: healthStatusFiles)

        // VO2Max files (MetricsMaxMetData)
        let metricsVO2Files = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Metrics"),
                                        prefix: "MetricsMaxMetData_", extension: "json")
        analyzeVO2Max(files: metricsVO2Files)

        // VO2Max files (ActivityVo2Max)
        let activityVO2Files = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Metrics"),
                                         prefix: "ActivityVo2Max_", extension: "json")
        analyzeActivityVO2Max(files: activityVO2Files)

        // Activity files
        let activityFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Fitness"),
                                      suffix: "_summarizedActivities.json")
        analyzeActivities(files: activityFiles)

        os_log("=== Analysis Pass Complete ===", log: GarminImporter.log, type: .info)
    }

    // MARK: - Import Pass

    /// Invoke each parser, collect all HKSamples, then save them.
    private func runImportPass(exportDirectory: URL, completion: @escaping () -> Void) {
        os_log("=== Garmin Import: Import Pass ===", log: GarminImporter.log, type: .info)

        let diConnect = exportDirectory.appendingPathComponent("DI_CONNECT")
        var allSamples: [HKSample] = []

        // UDS
        let udsFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Aggregator"),
                                 prefix: "UDSFile_", extension: "json")
        let udsSamples = parseFiles(files: udsFiles, parser: UDSParser())
        allSamples.append(contentsOf: udsSamples)

        // Hydration
        let hydrationFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Aggregator"),
                                       prefix: "HydrationLogFile_", extension: "json")
        let hydrationSamples = parseFiles(files: hydrationFiles, parser: HydrationParser())
        allSamples.append(contentsOf: hydrationSamples)

        // Sleep
        let sleepFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Wellness"),
                                   suffix: "_sleepData.json")
        let sleepSamples = parseFiles(files: sleepFiles, parser: SleepParser())
        allSamples.append(contentsOf: sleepSamples)

        // Health Status
        let healthStatusFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Wellness"),
                                          suffix: "_healthStatusData.json")
        let healthStatusSamples = parseFiles(files: healthStatusFiles, parser: HealthStatusParser())
        allSamples.append(contentsOf: healthStatusSamples)

        // VO2Max (MetricsMaxMetData)
        let metricsVO2Files = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Metrics"),
                                        prefix: "MetricsMaxMetData_", extension: "json")
        let vo2MaxSamples = parseFiles(files: metricsVO2Files, parser: VO2MaxParser())
        allSamples.append(contentsOf: vo2MaxSamples)

        // VO2Max (ActivityVo2Max)
        let activityVO2Files = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Metrics"),
                                         prefix: "ActivityVo2Max_", extension: "json")
        let activityVO2Samples = parseFiles(files: activityVO2Files, parser: ActivityVO2MaxParser())
        allSamples.append(contentsOf: activityVO2Samples)

        // Activities
        let activityFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Fitness"),
                                      suffix: "_summarizedActivities.json")
        let activitySamples = parseFiles(files: activityFiles, parser: ActivityParser())
        allSamples.append(contentsOf: activitySamples)

        // Body Weight (userBioMetrics)
        let biometricFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Wellness"),
                                       suffix: "_userBioMetrics.json")
        let biometricSamples = parseFiles(files: biometricFiles, parser: BiometricParser())
        allSamples.append(contentsOf: biometricSamples)

        // Nutrition (nutritionLogs)
        let nutritionFiles = findFiles(in: diConnect.appendingPathComponent("DI-Connect-Wellness"),
                                       suffix: "_nutritionLogs.json")
        let nutritionSamples = parseFiles(files: nutritionFiles, parser: NutritionParser())
        allSamples.append(contentsOf: nutritionSamples)

        // Filter out samples for denied types
        let authorizedSamples = allSamples.filter { sample in
            let status = healthStore.authorizationStatus(for: sample.sampleType)
            if status != .sharingAuthorized {
                return false
            }
            return true
        }

        os_log("Import pass collected %d samples (%d authorized)",
               log: GarminImporter.log, type: .info, allSamples.count, authorizedSamples.count)

        DispatchQueue.main.async {
            self.readCount = allSamples.count
            self.readCounterLabel?.text = "\(self.readCount)"
        }

        // Save samples (batch saving implemented in task 6.2)
        saveSamples(authorizedSamples) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    // MARK: - Batch Saving (placeholder — task 6.2 will implement full batching)

    /// Save collected samples to HealthKit. Task 6.2 will implement proper batching.
    private func saveSamples(_ samples: [HKSample], completion: @escaping () -> Void) {
        guard !samples.isEmpty else {
            os_log("No samples to save", log: GarminImporter.log, type: .info)
            completion()
            return
        }

        let chunks = stride(from: 0, to: samples.count, by: batchSize).map {
            Array(samples[$0..<min($0 + batchSize, samples.count)])
        }

        saveBatchesSequentially(chunks: chunks, index: 0, completion: completion)
    }

    private func saveBatchesSequentially(chunks: [[HKSample]], index: Int, completion: @escaping () -> Void) {
        guard index < chunks.count else {
            os_log("All %d batches saved", log: GarminImporter.log, type: .info, chunks.count)
            completion()
            return
        }

        let batch = chunks[index]
        healthStore.save(batch) { [weak self] success, error in
            guard let self = self else { return }

            if success {
                self.writeCount += batch.count
                DispatchQueue.main.async {
                    self.writeCounterLabel?.text = "\(self.writeCount)"
                }
                os_log("Saved batch %d/%d (%d samples)",
                       log: GarminImporter.log, type: .info, index + 1, chunks.count, batch.count)
            } else if let error = error {
                os_log("Batch %d/%d save failed: %{public}@",
                       log: GarminImporter.log, type: .error, index + 1, chunks.count, error.localizedDescription)
            }

            // Proceed with next batch regardless of success/failure
            self.saveBatchesSequentially(chunks: chunks, index: index + 1, completion: completion)
        }
    }

    // MARK: - File Discovery

    /// Find files in a directory matching a prefix and extension.
    private func findFiles(in directory: URL, prefix: String, extension ext: String) -> [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix(prefix) && url.pathExtension == ext
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Find files in a directory matching a suffix.
    private func findFiles(in directory: URL, suffix: String) -> [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.filter { url in
            url.lastPathComponent.hasSuffix(suffix)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Generic Parser Invocation

    /// Parse all files using the given parser, collecting all produced HKSamples.
    private func parseFiles<P: GarminParser>(files: [URL], parser: P) -> [HKSample] {
        var samples: [HKSample] = []
        for file in files {
            guard let data = try? Data(contentsOf: file) else {
                os_log("Failed to read file: %{public}@",
                       log: GarminImporter.log, type: .error, file.lastPathComponent)
                continue
            }
            do {
                let records = try parser.decode(data: data)
                for record in records {
                    let converted = parser.convert(record: record)
                    samples.append(contentsOf: converted)
                }
            } catch {
                os_log("Failed to decode %{public}@: %{public}@",
                       log: GarminImporter.log, type: .error,
                       file.lastPathComponent, error.localizedDescription)
            }
        }
        return samples
    }

    // MARK: - Analysis Helpers

    private func analyzeUDS(files: [URL]) {
        let parser = UDSParser()
        var totalRecords = 0
        var dates: [Date] = []
        var stepValues: [Double] = []
        var distanceValues: [Double] = []
        var activeCalValues: [Double] = []

        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let records = try? parser.decode(data: data) else { continue }
            totalRecords += records.count
            for record in records {
                if let dateStr = record.wellnessStartTimeLocal,
                   let date = GarminTimestampParser.parseLocal(dateStr) {
                    dates.append(date)
                }
                if let steps = record.totalSteps, steps > 0 {
                    stepValues.append(Double(steps))
                }
                if let dist = record.totalDistanceMeters, dist > 0 {
                    distanceValues.append(Double(dist))
                }
                if let cal = record.activeKilocalories, cal > 0 {
                    activeCalValues.append(cal)
                }
            }
        }

        os_log("UDS: %d files, %d records", log: GarminImporter.log, type: .info, files.count, totalRecords)
        logDateRange(dates: dates, label: "UDS")
        logStats(values: stepValues, label: "UDS Steps")
        logStats(values: distanceValues, label: "UDS Distance (m)")
        logStats(values: activeCalValues, label: "UDS Active Cal")
    }

    private func analyzeHydration(files: [URL]) {
        let parser = HydrationParser()
        var totalRecords = 0
        var dates: [Date] = []
        var values: [Double] = []

        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let records = try? parser.decode(data: data) else { continue }
            totalRecords += records.count
            for record in records {
                if let date = GarminTimestampParser.parseLocal(record.timestampLocal) {
                    dates.append(date)
                }
                if record.valueInML > 0 {
                    values.append(record.valueInML)
                }
            }
        }

        os_log("Hydration: %d files, %d records", log: GarminImporter.log, type: .info, files.count, totalRecords)
        logDateRange(dates: dates, label: "Hydration")
        logStats(values: values, label: "Hydration (mL)")
    }

    private func analyzeSleep(files: [URL]) {
        let parser = SleepParser()
        var totalRecords = 0
        var dates: [Date] = []

        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let records = try? parser.decode(data: data) else { continue }
            totalRecords += records.count
            for record in records {
                if let startStr = record.sleepStartTimestampGMT,
                   let date = GarminTimestampParser.parseGMT(startStr) {
                    dates.append(date)
                }
            }
        }

        os_log("Sleep: %d files, %d records", log: GarminImporter.log, type: .info, files.count, totalRecords)
        logDateRange(dates: dates, label: "Sleep")
    }

    private func analyzeHealthStatus(files: [URL]) {
        let parser = HealthStatusParser()
        var totalRecords = 0
        var dates: [Date] = []
        var hrvValues: [Double] = []
        var spo2Values: [Double] = []

        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let records = try? parser.decode(data: data) else { continue }
            totalRecords += records.count
            for record in records {
                if let date = GarminTimestampParser.parseGMT(record.createTimestampUTC) {
                    dates.append(date)
                }
                for metric in record.metrics {
                    guard let value = metric.value else { continue }
                    switch metric.type {
                    case "HRV": hrvValues.append(value)
                    case "SPO2": spo2Values.append(value)
                    default: break
                    }
                }
            }
        }

        os_log("HealthStatus: %d files, %d records", log: GarminImporter.log, type: .info, files.count, totalRecords)
        logDateRange(dates: dates, label: "HealthStatus")
        logStats(values: hrvValues, label: "HRV (ms)")
        logStats(values: spo2Values, label: "SpO2 (raw)")
    }

    private func analyzeVO2Max(files: [URL]) {
        let parser = VO2MaxParser()
        var totalRecords = 0
        var dates: [Date] = []
        var values: [Double] = []

        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let records = try? parser.decode(data: data) else { continue }
            totalRecords += records.count
            for record in records {
                if let date = GarminTimestampParser.parseGMT(record.updateTimestamp) {
                    dates.append(date)
                }
                if let vo2 = record.vo2MaxValue {
                    values.append(vo2)
                }
            }
        }

        os_log("VO2Max (Metrics): %d files, %d records", log: GarminImporter.log, type: .info, files.count, totalRecords)
        logDateRange(dates: dates, label: "VO2Max (Metrics)")
        logStats(values: values, label: "VO2Max (mL/kg·min)")
    }

    private func analyzeActivityVO2Max(files: [URL]) {
        let parser = ActivityVO2MaxParser()
        var totalRecords = 0
        var dates: [Date] = []
        var values: [Double] = []

        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let records = try? parser.decode(data: data) else { continue }
            totalRecords += records.count
            for record in records {
                if let date = GarminTimestampParser.parseGMT(record.timestampGmt) {
                    dates.append(date)
                }
                if let vo2 = record.vo2MaxValue {
                    values.append(vo2)
                }
            }
        }

        os_log("VO2Max (Activity): %d files, %d records", log: GarminImporter.log, type: .info, files.count, totalRecords)
        logDateRange(dates: dates, label: "VO2Max (Activity)")
        logStats(values: values, label: "ActivityVO2Max (mL/kg·min)")
    }

    private func analyzeActivities(files: [URL]) {
        let parser = ActivityParser()
        var totalRecords = 0
        var dates: [Date] = []
        var durationValues: [Double] = []
        var calorieValues: [Double] = []

        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let records = try? parser.decode(data: data) else { continue }
            totalRecords += records.count
            for record in records {
                let date = GarminTimestampParser.parseEpochMillis(record.startTimeGmt)
                dates.append(date)
                durationValues.append(record.duration / 1000.0 / 60.0) // minutes
                if let cal = record.calories, cal > 0 {
                    calorieValues.append(cal)
                }
            }
        }

        os_log("Activities: %d files, %d records", log: GarminImporter.log, type: .info, files.count, totalRecords)
        logDateRange(dates: dates, label: "Activities")
        logStats(values: durationValues, label: "Activity Duration (min)")
        logStats(values: calorieValues, label: "Activity Calories (kcal)")
    }

    // MARK: - Logging Utilities

    private func logDateRange(dates: [Date], label: String) {
        guard !dates.isEmpty else {
            os_log("  %{public}@: no dates found", log: GarminImporter.log, type: .info, label)
            return
        }
        let sorted = dates.sorted()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let earliest = formatter.string(from: sorted.first!)
        let latest = formatter.string(from: sorted.last!)
        os_log("  %{public}@ date range: %{public}@ to %{public}@",
               log: GarminImporter.log, type: .info, label, earliest, latest)
    }

    private func logStats(values: [Double], label: String) {
        guard !values.isEmpty else { return }
        let min = values.min()!
        let max = values.max()!
        let avg = values.reduce(0, +) / Double(values.count)
        os_log("  %{public}@: min=%.1f, max=%.1f, avg=%.1f (n=%d)",
               log: GarminImporter.log, type: .info, label, min, max, avg, values.count)
    }
}
