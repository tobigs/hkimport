//
//  GarminDirectoryDiscovery.swift
//  HKImport
//
//  Locates the Garmin export directory by searching for a directory
//  containing a DI_CONNECT subdirectory.
//

import Foundation
import os.log

struct GarminDirectoryDiscovery {

    /// Searches Documents directory, then app bundle, for a Garmin export directory.
    /// A valid directory contains a DI_CONNECT subdirectory.
    /// - Returns: URL of the Garmin export root directory, or nil if not found.
    static func findExportDirectory() -> URL? {
        if let docsDir = findInDocuments() { return docsDir }
        if let bundleDir = findInBundle() { return bundleDir }
        os_log("Garmin export directory not found in Documents or app bundle", type: .error)
        return nil
    }

    // MARK: - Private

    private static func findInDocuments() -> URL? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return searchForGarminExport(in: documentsURL)
    }

    private static func findInBundle() -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }

        // Check if DI_CONNECT exists directly at the bundle root (e.g. the UUID folder
        // was added as a folder reference and its contents land at the bundle root level).
        let diConnectAtRoot = resourceURL.appendingPathComponent("DI_CONNECT")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: diConnectAtRoot.path, isDirectory: &isDir), isDir.boolValue {
            return resourceURL
        }

        // Otherwise search one level deep for a subdirectory containing DI_CONNECT.
        return searchForGarminExport(in: resourceURL)
    }

    /// Searches for a subdirectory containing DI_CONNECT.
    /// - Parameter directory: The parent directory to search within.
    /// - Returns: URL of the first subdirectory containing a DI_CONNECT child, or nil.
    static func searchForGarminExport(in directory: URL) -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
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
