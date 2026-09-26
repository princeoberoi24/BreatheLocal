//
//  DuplicateContacts.swift
//  BreatheLocal
//

import Foundation

nonisolated struct ContactRecord: Identifiable, Hashable, Sendable {
    let id: String
    let givenName: String
    let familyName: String
    let middleName: String
    let namePrefix: String
    let nameSuffix: String
    let nickname: String
    let phoneticGivenName: String
    let phoneticFamilyName: String
    let organizationName: String
    let jobTitle: String
    let departmentName: String
    let formattedName: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
    let postalAddresses: [String]
    let urlAddresses: [String]
    let socialProfiles: [String]
    let instantMessageAddresses: [String]
    let dates: [String]
    let birthdayDescription: String
    let hasImageData: Bool
    var isKeep: Bool = false
    var isMarkedForDeletion: Bool = false

    var completenessScore: Int {
        phoneNumbers.count + emailAddresses.count + postalAddresses.count
            + (organizationName.isEmpty ? 0 : 1)
            + (hasImageData ? 1 : 0)
    }
}

nonisolated struct DuplicateContacts: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var memberCount: Int
    var members: [ContactRecord]

    var deletionCount: Int {
        members.filter(\.isMarkedForDeletion).count
    }
}
