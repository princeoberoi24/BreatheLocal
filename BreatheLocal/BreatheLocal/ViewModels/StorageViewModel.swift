//
//  StorageViewModel.swift
//  BreatheLocal
//

import Foundation
import Observation
import Photos

enum ScanState: String, Sendable {
    case idle
    case scanning
    case completed
}

enum DeletionEngineError: Error, Sendable, Equatable {
    case mediaFailed
    case contactsFailed
}

@Observable
final class StorageViewModel {
    private let storageManager = StorageManager()
    private let mediaScanner = MediaScanner()
    private let contactManager = ContactManager()

    var scanState: ScanState = .idle
    var storageMetrics: StorageMetrics = .zero

    var similarPhotos: [SimilarPhotos] = []
    var screenshots: [Screenshots] = []
    var largeVideos: [LargeVideos] = []
    var duplicateContacts: [DuplicateContacts] = []
    var contactAccessError: ContactAccessError?
    var photoAccessError: PhotoAccessError?

    var isDeleting = false
    var deletionErrorMessage: String?

    var pendingMediaIdentifiers: [String] {
        let similarIDs = similarPhotos.flatMap { group in
            group.members.filter(\.isMarkedForDeletion).map(\.id)
        }
        let screenshotIDs = screenshots.filter(\.isMarkedForDeletion).map(\.id)
        let videoIDs = largeVideos.filter(\.isMarkedForDeletion).map(\.id)
        return Array(Set(similarIDs + screenshotIDs + videoIDs))
    }

    var pendingContactIDs: [String] {
        duplicateContacts.flatMap { group in
            group.members.filter(\.isMarkedForDeletion).map(\.id)
        }
    }

    var stagedScreenshotCount: Int {
        screenshots.filter(\.isMarkedForDeletion).count
    }

    var stagedVideoCount: Int {
        largeVideos.filter(\.isMarkedForDeletion).count
    }

    var stagedContactCount: Int {
        pendingContactIDs.count
    }

    var pendingContactJobs: [ContactMergeJob] {
        duplicateContacts.compactMap { group in
            let deleteIDs = group.members.filter(\.isMarkedForDeletion).map(\.id)
            guard !deleteIDs.isEmpty else { return nil }
            return ContactMergeJob(
                keeperID: group.members.first(where: \.isKeep)?.id,
                deleteIDs: deleteIDs
            )
        }
    }

    var pendingDeletionCount: Int {
        pendingMediaIdentifiers.count + pendingContactIDs.count
    }

    var pendingReclaimableDisplay: String {
        let bytes = similarPhotos.flatMap(\.members).filter(\.isMarkedForDeletion).map(\.byteSize)
            + screenshots.filter(\.isMarkedForDeletion).map(\.byteSize)
            + largeVideos.filter(\.isMarkedForDeletion).map(\.byteSize)
        let total = bytes.reduce(Int64(0), +)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }

    private func clearManualStaging() {
        for index in screenshots.indices {
            screenshots[index].isMarkedForDeletion = false
        }
        for index in largeVideos.indices {
            largeVideos[index].isMarkedForDeletion = false
        }
    }

    private func clearContactStaging() {
        for groupIndex in duplicateContacts.indices {
            for memberIndex in duplicateContacts[groupIndex].members.indices {
                duplicateContacts[groupIndex].members[memberIndex].isMarkedForDeletion = false
            }
        }
    }

    func refreshStorageMetrics() async {
        storageMetrics = await storageManager.storageMetrics()
    }

    func startScan() async {
        scanState = .scanning
        await refreshStorageMetrics()
        await storageManager.startScan()
        await refreshMediaLibrary()
        await refreshDuplicateContacts()
        scanState = .completed
    }

    func refreshMediaLibrary() async {
        do {
            let result = try await mediaScanner.startScan()
            largeVideos = result.videos
            screenshots = result.screenshots
            similarPhotos = result.similarPhotos
            clearManualStaging()
            photoAccessError = nil
        } catch let error as PhotoAccessError {
            largeVideos = []
            screenshots = []
            similarPhotos = []
            photoAccessError = error
        } catch {
            largeVideos = []
            screenshots = []
            similarPhotos = []
            photoAccessError = .fetchFailed
        }
    }

    func refreshDuplicateContacts() async {
        do {
            duplicateContacts = try await contactManager.startScan()
            clearContactStaging()
            contactAccessError = nil
        } catch let error as ContactAccessError {
            duplicateContacts = []
            contactAccessError = error
        } catch {
            duplicateContacts = []
            contactAccessError = .fetchFailed
        }
    }

    func toggleScreenshotMarked(id: String) {
        markScreenshot(id: id, stagedForDeletion: !(screenshots.first(where: { $0.id == id })?.isMarkedForDeletion ?? false))
    }

    func markScreenshot(id: String, stagedForDeletion: Bool) {
        guard let index = screenshots.firstIndex(where: { $0.id == id }) else { return }
        screenshots[index].isMarkedForDeletion = stagedForDeletion
    }

    func toggleVideoMarked(id: String) {
        markVideo(id: id, stagedForDeletion: !(largeVideos.first(where: { $0.id == id })?.isMarkedForDeletion ?? false))
    }

    func markVideo(id: String, stagedForDeletion: Bool) {
        guard let index = largeVideos.firstIndex(where: { $0.id == id }) else { return }
        largeVideos[index].isMarkedForDeletion = stagedForDeletion
    }

    func markSimilarPhoto(groupID: UUID, memberID: String, stagedForDeletion: Bool) {
        guard let groupIndex = similarPhotos.firstIndex(where: { $0.id == groupID }),
              let memberIndex = similarPhotos[groupIndex].members.firstIndex(where: { $0.id == memberID })
        else { return }

        similarPhotos[groupIndex].members[memberIndex].isMarkedForDeletion = stagedForDeletion
        similarPhotos[groupIndex].members[memberIndex].isKeep = !stagedForDeletion
        if !stagedForDeletion {
            similarPhotos[groupIndex].keepAssetID = memberID
        }
    }

    func markContact(groupID: UUID, memberID: String, stagedForDeletion: Bool) {
        guard let groupIndex = duplicateContacts.firstIndex(where: { $0.id == groupID }),
              let memberIndex = duplicateContacts[groupIndex].members.firstIndex(where: { $0.id == memberID })
        else { return }

        duplicateContacts[groupIndex].members[memberIndex].isMarkedForDeletion = stagedForDeletion
        duplicateContacts[groupIndex].members[memberIndex].isKeep = !stagedForDeletion
    }

    func unstagePendingMedia(id: String) {
        if screenshots.contains(where: { $0.id == id }) {
            markScreenshot(id: id, stagedForDeletion: false)
            return
        }
        if largeVideos.contains(where: { $0.id == id }) {
            markVideo(id: id, stagedForDeletion: false)
            return
        }
        for group in similarPhotos {
            if group.members.contains(where: { $0.id == id }) {
                markSimilarPhoto(groupID: group.id, memberID: id, stagedForDeletion: false)
                return
            }
        }
    }

    func unstagePendingContact(id: String) {
        for group in duplicateContacts {
            if group.members.contains(where: { $0.id == id }) {
                markContact(groupID: group.id, memberID: id, stagedForDeletion: false)
                return
            }
        }
    }

    func fileSizeDisplay(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func confirmPendingDeletions() async {
        guard !isDeleting, pendingDeletionCount > 0 else { return }

        isDeleting = true
        deletionErrorMessage = nil
        defer { isDeleting = false }

        var mediaSucceeded = false
        var contactsSucceeded = false
        var failures: [String] = []

        let mediaIDs = pendingMediaIdentifiers
        if !mediaIDs.isEmpty {
            do {
                try await deleteSelectedMedia(identifiers: mediaIDs)
                mediaSucceeded = true
            } catch {
                failures.append("Photos and videos could not be removed from the library.")
            }
        }

        let contactJobs = pendingContactJobs
        if !contactJobs.isEmpty {
            do {
                try await contactManager.mergeAndDelete(contactJobs)
                contactsSucceeded = true
            } catch let error as ContactAccessError where error == .denied || error == .restricted {
                failures.append("Contacts access was denied, so duplicate records were not changed.")
            } catch {
                failures.append("Duplicate contacts could not be merged or deleted.")
            }
        }

        if mediaSucceeded || contactsSucceeded {
            await refreshStorageMetrics()
        }

        if mediaSucceeded {
            await refreshMediaLibrary()
        }
        if contactsSucceeded {
            await refreshDuplicateContacts()
        }

        if !failures.isEmpty {
            deletionErrorMessage = failures.joined(separator: " ")
        }
    }

    private func deleteSelectedMedia(identifiers: [String]) async throws {
        let uniqueIDs = Array(Set(identifiers))
        guard !uniqueIDs.isEmpty else { return }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: uniqueIDs, options: nil)
                guard assets.count > 0 else { return }
                PHAssetChangeRequest.deleteAssets(assets)
            }
        } catch {
            throw DeletionEngineError.mediaFailed
        }
    }
}
