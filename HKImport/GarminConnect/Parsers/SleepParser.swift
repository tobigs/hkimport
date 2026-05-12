//
//  SleepParser.swift
//  HKImport
//
//  Parses Garmin sleep data JSON files and converts records into HealthKit
//  category samples for sleep stages (deep, core/light, REM, awake).
//  Stages are distributed sequentially within the sleep window.
//

import Foundation
import HealthKit
import os.log

struct SleepParser: GarminParser {
    typealias RecordType = GarminSleepRecord

    func decode(data: Data) throws -> [GarminSleepRecord] {
        let decoder = JSONDecoder()
        return try decoder.decode([GarminSleepRecord].self, from: data)
    }

    func convert(record: GarminSleepRecord) -> [HKSample] {
        // Skip records missing the essential sleep window or stage fields
        // (e.g. entries like {"retro": false} or nap-only records).
        guard let startString = record.sleepStartTimestampGMT,
              let endString = record.sleepEndTimestampGMT,
              let startDate = GarminTimestampParser.parseGMT(startString),
              let _ = GarminTimestampParser.parseGMT(endString) else {
            return []
        }

        // Sleep stage values require iOS 16+
        guard #available(iOS 16.0, *) else {
            os_log("SleepParser: skipping record — sleep stages require iOS 16+",
                   log: .default, type: .info)
            return []
        }

        let metadata = GarminDeviceFactory.metadata(calendarDate: record.calendarDate)
        let device = GarminDeviceFactory.device

        var samples: [HKSample] = []
        var cursor = startDate

        // Deep sleep
        if let seconds = record.deepSleepSeconds, seconds > 0 {
            let stageEnd = cursor.addingTimeInterval(TimeInterval(seconds))
            let sample = HKCategorySample(
                type: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
                value: HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                start: cursor,
                end: stageEnd,
                device: device,
                metadata: metadata
            )
            samples.append(sample)
            cursor = stageEnd
        }

        // Core (light) sleep
        if let seconds = record.lightSleepSeconds, seconds > 0 {
            let stageEnd = cursor.addingTimeInterval(TimeInterval(seconds))
            let sample = HKCategorySample(
                type: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
                value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                start: cursor,
                end: stageEnd,
                device: device,
                metadata: metadata
            )
            samples.append(sample)
            cursor = stageEnd
        }

        // REM sleep (optional field — may be nil or zero)
        if let remSeconds = record.remSleepSeconds, remSeconds > 0 {
            let stageEnd = cursor.addingTimeInterval(TimeInterval(remSeconds))
            let sample = HKCategorySample(
                type: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
                value: HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                start: cursor,
                end: stageEnd,
                device: device,
                metadata: metadata
            )
            samples.append(sample)
            cursor = stageEnd
        }

        // Awake
        if let seconds = record.awakeSleepSeconds, seconds > 0 {
            let stageEnd = cursor.addingTimeInterval(TimeInterval(seconds))
            let sample = HKCategorySample(
                type: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
                value: HKCategoryValueSleepAnalysis.awake.rawValue,
                start: cursor,
                end: stageEnd,
                device: device,
                metadata: metadata
            )
            samples.append(sample)
            cursor = stageEnd
        }

        return samples
    }
}
