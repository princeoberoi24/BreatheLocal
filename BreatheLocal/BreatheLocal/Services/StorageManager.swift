//
//  StorageManager.swift
//  BreatheLocal
//

import Foundation

nonisolated struct StorageMetrics: Sendable {
    let totalBytes: Int64
    let usedBytes: Int64
    let freeBytes: Int64
    let totalDisplay: String
    let usedDisplay: String
    let freeDisplay: String

    static let zero: StorageMetrics = {
        let formatter = StorageManager.makeFileCountFormatter()
        let zeroDisplay = formatter.string(fromByteCount: 0)
        return StorageMetrics(
            totalBytes: 0,
            usedBytes: 0,
            freeBytes: 0,
            totalDisplay: zeroDisplay,
            usedDisplay: zeroDisplay,
            freeDisplay: zeroDisplay
        )
    }()
}

actor StorageManager: Sendable {
    private let fileManager = FileManager()
    private let byteFormatter = StorageManager.makeFileCountFormatter()

    func startScan() async {
        _ = storageMetrics()
    }

    func storageMetrics() -> StorageMetrics {
        let path = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.path
            ?? NSHomeDirectory()

        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: path)
            let totalBytes = int64Value(attributes[.systemSize])
            let freeBytes = int64Value(attributes[.systemFreeSize])
            let usedBytes = max(totalBytes - freeBytes, 0)
            return StorageMetrics(
                totalBytes: totalBytes,
                usedBytes: usedBytes,
                freeBytes: freeBytes,
                totalDisplay: formattedFileCount(totalBytes),
                usedDisplay: formattedFileCount(usedBytes),
                freeDisplay: formattedFileCount(freeBytes)
            )
        } catch {
            return .zero
        }
    }

    nonisolated fileprivate static func makeFileCountFormatter() -> ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }

    private func formattedFileCount(_ bytes: Int64) -> String {
        byteFormatter.string(fromByteCount: bytes)
    }

    private func int64Value(_ value: Any?) -> Int64 {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let int64 = value as? Int64 {
            return int64
        }
        if let uint64 = value as? UInt64 {
            return Int64(clamping: uint64)
        }
        return 0
    }
}



