//
//  MediaScanner.swift
//  BreatheLocal
//

import AVFoundation
import Foundation
import Photos

nonisolated enum PhotoAccessError: Error, Sendable, Equatable {
    case denied
    case restricted
    case fetchFailed
}

nonisolated struct MediaScanResult: Sendable {
    let videos: [LargeVideos]
    let screenshots: [Screenshots]
    let similarPhotos: [SimilarPhotos]
}

actor MediaScanner: Sendable {
    /// Close-capture window inside the assigned 2–5 second range.
    private static let similarCaptureThreshold: TimeInterval = 5
    private static let recentPhotoLimit = 500

    private let byteFormatter = MediaScanner.makeFileCountFormatter()

    func startScan() async throws -> MediaScanResult {
        try await requestAccess()
        let videos = await collectLargeVideos()
        let screenshots = await collectScreenshots()
        let similarPhotos = await collectSimilarPhotos()
        return MediaScanResult(videos: videos, screenshots: screenshots, similarPhotos: similarPhotos)
    }

    private func requestAccess() async throws {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            return
        case .denied:
            throw PhotoAccessError.denied
        case .restricted:
            throw PhotoAccessError.restricted
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            switch status {
            case .authorized, .limited:
                return
            case .denied:
                throw PhotoAccessError.denied
            case .restricted:
                throw PhotoAccessError.restricted
            case .notDetermined:
                throw PhotoAccessError.fetchFailed
            @unknown default:
                throw PhotoAccessError.denied
            }
        @unknown default:
            throw PhotoAccessError.denied
        }
    }

    private func collectLargeVideos() async -> [LargeVideos] {
        let assets = fetchLocalVideos()
        var videos: [LargeVideos] = []
        videos.reserveCapacity(assets.count)

        for asset in assets {
            let byteSize = await resolvedVideoFileSize(for: asset)
            videos.append(
                LargeVideos(
                    id: asset.localIdentifier,
                    displayName: displayName(
                        for: asset,
                        resourceTypes: [.video, .fullSizeVideo, .pairedVideo],
                        fallback: "Video"
                    ),
                    byteSize: byteSize,
                    byteSizeDisplay: formattedFileCount(byteSize),
                    isMarkedForDeletion: false
                )
            )
        }

        return videos.sorted { $0.byteSize > $1.byteSize }
    }

    private func collectScreenshots() async -> [Screenshots] {
        let assets = fetchLocalScreenshots()
        var screenshots: [Screenshots] = []
        screenshots.reserveCapacity(assets.count)

        for asset in assets {
            let byteSize = await resolvedImageFileSize(for: asset)
            screenshots.append(
                Screenshots(
                    id: asset.localIdentifier,
                    displayName: displayName(
                        for: asset,
                        resourceTypes: [.photo, .fullSizePhoto, .alternatePhoto],
                        fallback: "Screenshot"
                    ),
                    byteSize: byteSize,
                    byteSizeDisplay: formattedFileCount(byteSize),
                    creationDate: asset.creationDate,
                    isMarkedForDeletion: false
                )
            )
        }

        return screenshots.sorted { lhs, rhs in
            (lhs.creationDate ?? .distantPast) > (rhs.creationDate ?? .distantPast)
        }
    }

    private func collectSimilarPhotos() async -> [SimilarPhotos] {
        let assets = fetchRecentUserPhotos()
        var candidates: [PhotoCandidate] = []
        candidates.reserveCapacity(assets.count)

        for asset in assets {
            let byteSize = await resolvedImageFileSize(for: asset)
            candidates.append(
                PhotoCandidate(
                    localIdentifier: asset.localIdentifier,
                    displayName: displayName(
                        for: asset,
                        resourceTypes: [.photo, .fullSizePhoto, .alternatePhoto],
                        fallback: "Photo"
                    ),
                    byteSize: byteSize,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    creationDate: asset.creationDate,
                    burstIdentifier: asset.burstIdentifier,
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude,
                    isFavorite: asset.isFavorite
                )
            )
        }

        return autoSelectKeepers(in: groupSimilarCandidates(candidates))
    }

    private func fetchRecentUserPhotos() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND NOT ((mediaSubtypes & %d) != 0)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = Self.recentPhotoLimit
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = [.typeUserLibrary]

        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            guard !asset.mediaSubtypes.contains(.photoScreenshot) else { return }
            assets.append(asset)
        }
        return assets
    }

    private func groupSimilarCandidates(_ candidates: [PhotoCandidate]) -> [[PhotoCandidate]] {
        guard candidates.count > 1 else { return [] }

        var unionFind = UnionFind(count: candidates.count)
        let chronological = candidates.enumerated()
            .sorted { lhs, rhs in
                (lhs.element.creationDate ?? .distantPast) < (rhs.element.creationDate ?? .distantPast)
            }

        for (offset, current) in chronological.enumerated() {
            guard offset + 1 < chronological.count else { continue }
            let next = chronological[offset + 1]
            if areWithinCaptureThreshold(current.element, next.element) {
                unionFind.union(current.offset, next.offset)
            }
        }

        var burstBuckets: [String: [Int]] = [:]
        for (index, candidate) in candidates.enumerated() {
            if let burst = candidate.burstIdentifier, !burst.isEmpty {
                burstBuckets[burst, default: []].append(index)
            }
        }

        for indexes in burstBuckets.values where indexes.count > 1 {
            let root = indexes[0]
            for index in indexes.dropFirst() {
                unionFind.union(root, index)
            }
        }

        var clustered: [Int: [PhotoCandidate]] = [:]
        for index in candidates.indices {
            clustered[unionFind.find(index), default: []].append(candidates[index])
        }
        return clustered.values.filter { $0.count > 1 }
    }

    private func autoSelectKeepers(in groups: [[PhotoCandidate]]) -> [SimilarPhotos] {
        groups.compactMap { members in
            guard let keep = bestQualityCandidate(in: members) else { return nil }

            let selected = members
                .map { member in
                    let isKeep = member.localIdentifier == keep.localIdentifier
                    return SimilarPhotoMember(
                        id: member.localIdentifier,
                        displayName: member.displayName,
                        byteSize: member.byteSize,
                        byteSizeDisplay: formattedFileCount(member.byteSize),
                        pixelWidth: member.pixelWidth,
                        pixelHeight: member.pixelHeight,
                        creationDate: member.creationDate,
                        isKeep: isKeep,
                        isMarkedForDeletion: !isKeep
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.isKeep != rhs.isKeep {
                        return lhs.isKeep && !rhs.isKeep
                    }
                    return (lhs.creationDate ?? .distantPast) > (rhs.creationDate ?? .distantPast)
                }

            let reclaimableBytes = selected
                .filter(\.isMarkedForDeletion)
                .reduce(Int64(0)) { $0 + $1.byteSize }

            return SimilarPhotos(
                id: UUID(),
                displayName: similarGroupTitle(for: selected),
                byteSize: reclaimableBytes,
                byteSizeDisplay: formattedFileCount(reclaimableBytes),
                keepAssetID: keep.localIdentifier,
                members: selected
            )
        }
        .sorted { lhs, rhs in
            let leftDate = lhs.members.compactMap(\.creationDate).max() ?? .distantPast
            let rightDate = rhs.members.compactMap(\.creationDate).max() ?? .distantPast
            return leftDate > rightDate
        }
    }

    private func bestQualityCandidate(in members: [PhotoCandidate]) -> PhotoCandidate? {
        members.max { lhs, rhs in
            if lhs.pixelArea != rhs.pixelArea {
                return lhs.pixelArea < rhs.pixelArea
            }
            let leftDate = lhs.creationDate ?? .distantFuture
            let rightDate = rhs.creationDate ?? .distantFuture
            if leftDate != rightDate {
                return leftDate > rightDate
            }
            return false
        }
    }

    private func similarGroupTitle(for members: [SimilarPhotoMember]) -> String {
        if let date = members.compactMap(\.creationDate).max() {
            return "\(members.count) similar · \(date.formatted(date: .abbreviated, time: .shortened))"
        }
        return "\(members.count) similar photos"
    }

    private func areWithinCaptureThreshold(_ lhs: PhotoCandidate, _ rhs: PhotoCandidate) -> Bool {
        guard let leftDate = lhs.creationDate, let rightDate = rhs.creationDate else {
            return false
        }
        return abs(leftDate.timeIntervalSince(rightDate)) <= Self.similarCaptureThreshold
    }

    private func fetchLocalVideos() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = [.typeUserLibrary]

        let fetchResult = PHAsset.fetchAssets(with: .video, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func fetchLocalScreenshots() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND ((mediaSubtypes & %d) != 0)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = [.typeUserLibrary]

        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            guard asset.mediaSubtypes.contains(.photoScreenshot) else { return }
            assets.append(asset)
        }
        return assets
    }

    private func resolvedVideoFileSize(for asset: PHAsset) async -> Int64 {
        let resourceSize = resourceFileSize(
            for: asset,
            preferredTypes: [.video, .fullSizeVideo, .pairedVideo, .adjustmentBaseVideo]
        )
        if resourceSize > 0 {
            return resourceSize
        }
        return await localAVFileSize(for: asset)
    }

    private func resolvedImageFileSize(for asset: PHAsset) async -> Int64 {
        let resourceSize = resourceFileSize(
            for: asset,
            preferredTypes: [.photo, .fullSizePhoto, .alternatePhoto, .adjustmentBasePhoto]
        )
        if resourceSize > 0 {
            return resourceSize
        }
        return await localImageFileSize(for: asset)
    }

    private func resourceFileSize(
        for asset: PHAsset,
        preferredTypes: [PHAssetResourceType]
    ) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        for type in preferredTypes {
            guard let resource = resources.first(where: { $0.type == type }) else {
                continue
            }
            if let size = fileSize(from: resource), size > 0 {
                return size
            }
        }
        return 0
    }

    private func fileSize(from resource: PHAssetResource) -> Int64? {
        let value = resource.value(forKey: "fileSize")
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let int64 = value as? Int64 {
            return int64
        }
        if let uint64 = value as? UInt64 {
            return Int64(clamping: uint64)
        }
        return nil
    }

    private func localAVFileSize(for asset: PHAsset) async -> Int64 {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false
            options.version = .original
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: Self.fileSize(from: avAsset))
            }
        }
    }

    private func localImageFileSize(for asset: PHAsset) async -> Int64 {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.version = .original
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: Int64(data?.count ?? 0))
            }
        }
    }

    private func displayName(
        for asset: PHAsset,
        resourceTypes: [PHAssetResourceType],
        fallback: String
    ) -> String {
        let resources = PHAssetResource.assetResources(for: asset)
        if let filename = resources.first(where: { resourceTypes.contains($0.type) })?
            .originalFilename.trimmingCharacters(in: .whitespacesAndNewlines),
           !filename.isEmpty {
            return filename
        }
        if let date = asset.creationDate {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return fallback
    }

    private func formattedFileCount(_ bytes: Int64) -> String {
        byteFormatter.string(fromByteCount: bytes)
    }

    private static func fileSize(from avAsset: AVAsset?) -> Int64 {
        guard let urlAsset = avAsset as? AVURLAsset else { return 0 }
        guard let fileSize = try? urlAsset.url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return 0
        }
        return Int64(fileSize)
    }

    nonisolated fileprivate static func makeFileCountFormatter() -> ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }
}

private struct PhotoCandidate {
    let localIdentifier: String
    let displayName: String
    let byteSize: Int64
    let pixelWidth: Int
    let pixelHeight: Int
    let creationDate: Date?
    let burstIdentifier: String?
    let latitude: Double?
    let longitude: Double?
    let isFavorite: Bool

    var pixelArea: Int {
        pixelWidth * pixelHeight
    }
}

private struct UnionFind {
    private var parent: [Int]
    private var rank: [Int]

    init(count: Int) {
        parent = Array(0..<count)
        rank = Array(repeating: 0, count: count)
    }

    mutating func find(_ x: Int) -> Int {
        if parent[x] != x {
            parent[x] = find(parent[x])
        }
        return parent[x]
    }

    mutating func union(_ a: Int, _ b: Int) {
        let rootA = find(a)
        let rootB = find(b)
        guard rootA != rootB else { return }
        if rank[rootA] < rank[rootB] {
            parent[rootA] = rootB
        } else if rank[rootA] > rank[rootB] {
            parent[rootB] = rootA
        } else {
            parent[rootB] = rootA
            rank[rootA] += 1
        }
    }
}
