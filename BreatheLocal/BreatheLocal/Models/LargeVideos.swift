//
//  LargeVideos.swift
//  BreatheLocal
//

import Foundation

nonisolated struct LargeVideos: Identifiable, Hashable, Sendable {
    let id: String
    var displayName: String
    var byteSize: Int64
    var byteSizeDisplay: String
    var isMarkedForDeletion: Bool = false
}
