//
//  SimilarPhotos.swift
//  BreatheLocal
//

import Foundation

nonisolated struct SimilarPhotoMember: Identifiable, Hashable, Sendable {
    let id: String
    var displayName: String
    var byteSize: Int64
    var byteSizeDisplay: String
    var pixelWidth: Int
    var pixelHeight: Int
    var creationDate: Date?
    var isKeep: Bool
    var isMarkedForDeletion: Bool
}

nonisolated struct SimilarPhotos: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var byteSize: Int64
    var byteSizeDisplay: String
    var keepAssetID: String
    var members: [SimilarPhotoMember]

    var deletionCount: Int {
        members.filter(\.isMarkedForDeletion).count
    }

    var reclaimableBytes: Int64 {
        members.filter(\.isMarkedForDeletion).reduce(Int64(0)) { $0 + $1.byteSize }
    }
}
