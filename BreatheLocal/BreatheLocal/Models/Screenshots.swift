//
//  Screenshots.swift
//  BreatheLocal
//

import Foundation

nonisolated struct Screenshots: Identifiable, Hashable, Sendable {
    let id: String
    var displayName: String
    var byteSize: Int64
    var byteSizeDisplay: String
    var creationDate: Date?
    var isMarkedForDeletion: Bool = false
}
