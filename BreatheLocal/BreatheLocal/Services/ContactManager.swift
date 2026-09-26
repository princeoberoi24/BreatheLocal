//
//  ContactManager.swift
//  BreatheLocal
//

import Contacts
import Foundation

nonisolated enum ContactAccessError: Error, Sendable, Equatable {
    case denied
    case restricted
    case fetchFailed
    case saveFailed
}

nonisolated struct ContactMergeJob: Sendable {
    let keeperID: String?
    let deleteIDs: [String]
}

actor ContactManager: Sendable {
    private let store = CNContactStore()

    func startScan() async throws -> [DuplicateContacts] {
        try await requestAccess()
        let records = try fetchAccessibleContacts()
        return duplicateGroups(from: records)
    }

    func mergeAndDelete(_ jobs: [ContactMergeJob]) async throws {
        try await requestAccess()
        let saveRequest = CNSaveRequest()
        var hasChanges = false

        for job in jobs {
            let deleteIDs = job.deleteIDs.filter { $0 != job.keeperID }
            guard !deleteIDs.isEmpty else { continue }

            var keeper: CNMutableContact?
            if let keeperID = job.keeperID {
                keeper = mutableContact(identifier: keeperID)
            }

            for deleteID in deleteIDs {
                guard let other = mutableContact(identifier: deleteID) else { continue }
                if let keeper {
                    mergeUniqueFields(from: other, into: keeper)
                }
                saveRequest.delete(other)
                hasChanges = true
            }

            if let keeper {
                saveRequest.update(keeper)
                hasChanges = true
            }
        }

        guard hasChanges else { return }
        do {
            try store.execute(saveRequest)
        } catch let error as ContactAccessError {
            throw error
        } catch {
            throw mappedAccessError(error) == .denied ? ContactAccessError.denied : .saveFailed
        }
    }

    private func requestAccess() async throws {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            return
        case .denied:
            throw ContactAccessError.denied
        case .restricted:
            throw ContactAccessError.restricted
        case .notDetermined:
            do {
                let granted = try await store.requestAccess(for: .contacts)
                guard granted else {
                    throw ContactAccessError.denied
                }
            } catch let error as ContactAccessError {
                throw error
            } catch {
                throw mappedAccessError(error)
            }
        @unknown default:
            throw ContactAccessError.denied
        }
    }

    private func fetchAccessibleContacts() throws -> [ContactRecord] {
        let request = CNContactFetchRequest(keysToFetch: Self.fetchKeys)
        request.unifyResults = true

        var records: [ContactRecord] = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                records.append(Self.record(from: contact))
            }
        } catch {
            throw mappedAccessError(error)
        }
        return records
    }

    private func duplicateGroups(from records: [ContactRecord]) -> [DuplicateContacts] {
        let groupable = records.filter { !$0.givenName.isEmpty || !$0.familyName.isEmpty }
        let buckets = Dictionary(grouping: groupable) { record in
            NameKey(givenName: record.givenName, familyName: record.familyName)
        }

        return buckets
            .compactMap { key, members in
                guard members.count > 1 else { return nil }
                let sortedMembers = members.sorted { lhs, rhs in
                    lhs.formattedName.localizedStandardCompare(rhs.formattedName) == .orderedAscending
                }
                let keepID = bestContact(in: sortedMembers)?.id
                let selected = sortedMembers.map { member in
                    var updated = member
                    updated.isKeep = member.id == keepID
                    updated.isMarkedForDeletion = false
                    return updated
                }
                return DuplicateContacts(
                    id: UUID(),
                    displayName: key.displayName,
                    memberCount: selected.count,
                    members: selected
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    private func bestContact(in members: [ContactRecord]) -> ContactRecord? {
        members.max { lhs, rhs in
            if lhs.completenessScore != rhs.completenessScore {
                return lhs.completenessScore < rhs.completenessScore
            }
            return lhs.formattedName.localizedStandardCompare(rhs.formattedName) == .orderedAscending
        }
    }

    private func mutableContact(identifier: String) -> CNMutableContact? {
        do {
            let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: Self.mutationKeys)
            return contact.mutableCopy() as? CNMutableContact
        } catch {
            return nil
        }
    }

    private func mergeUniqueFields(from other: CNContact, into keeper: CNMutableContact) {
        let existingPhones = Set(keeper.phoneNumbers.map(\.value.stringValue))
        for labeled in other.phoneNumbers where !existingPhones.contains(labeled.value.stringValue) {
            keeper.phoneNumbers.append(labeled)
        }

        let existingEmails = Set(keeper.emailAddresses.map { $0.value as String })
        for labeled in other.emailAddresses where !existingEmails.contains(labeled.value as String) {
            keeper.emailAddresses.append(labeled)
        }

        if keeper.organizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keeper.organizationName = other.organizationName
        }
    }

    private func mappedAccessError(_ error: Error) -> ContactAccessError {
        if let cnError = error as? CNError, cnError.code == .authorizationDenied {
            return .denied
        }
        return .fetchFailed
    }
}

private struct NameKey: Hashable {
    let givenName: String
    let familyName: String

    var displayName: String {
        let combined = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "Unnamed Contact" : combined
    }
}

private extension ContactManager {
    static let fetchKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactNamePrefixKey as CNKeyDescriptor,
        CNContactNameSuffixKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactPhoneticGivenNameKey as CNKeyDescriptor,
        CNContactPhoneticFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactDepartmentNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactSocialProfilesKey as CNKeyDescriptor,
        CNContactInstantMessageAddressesKey as CNKeyDescriptor,
        CNContactDatesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]

    static let mutationKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor
    ]

    static func record(from contact: CNContact) -> ContactRecord {
        ContactRecord(
            id: contact.identifier,
            givenName: string(contact, CNContactGivenNameKey, contact.givenName),
            familyName: string(contact, CNContactFamilyNameKey, contact.familyName),
            middleName: string(contact, CNContactMiddleNameKey, contact.middleName),
            namePrefix: string(contact, CNContactNamePrefixKey, contact.namePrefix),
            nameSuffix: string(contact, CNContactNameSuffixKey, contact.nameSuffix),
            nickname: string(contact, CNContactNicknameKey, contact.nickname),
            phoneticGivenName: string(contact, CNContactPhoneticGivenNameKey, contact.phoneticGivenName),
            phoneticFamilyName: string(contact, CNContactPhoneticFamilyNameKey, contact.phoneticFamilyName),
            organizationName: string(contact, CNContactOrganizationNameKey, contact.organizationName),
            jobTitle: string(contact, CNContactJobTitleKey, contact.jobTitle),
            departmentName: string(contact, CNContactDepartmentNameKey, contact.departmentName),
            formattedName: formattedName(from: contact),
            phoneNumbers: phoneNumbers(from: contact),
            emailAddresses: stringValues(contact, CNContactEmailAddressesKey, contact.emailAddresses),
            postalAddresses: postalAddresses(from: contact),
            urlAddresses: stringValues(contact, CNContactUrlAddressesKey, contact.urlAddresses),
            socialProfiles: socialProfiles(from: contact),
            instantMessageAddresses: instantMessages(from: contact),
            dates: dates(from: contact),
            birthdayDescription: birthdayDescription(from: contact),
            hasImageData: contact.isKeyAvailable(CNContactImageDataAvailableKey) && contact.imageDataAvailable
        )
    }

    static func formattedName(from contact: CNContact) -> String {
        if let name = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        let fallback = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return fallback.isEmpty ? "Unnamed Contact" : fallback
    }

    static func string(_ contact: CNContact, _ key: String, _ value: @autoclosure () -> String) -> String {
        guard contact.isKeyAvailable(key) else { return "" }
        return value()
    }

    static func stringValues(
        _ contact: CNContact,
        _ key: String,
        _ values: @autoclosure () -> [CNLabeledValue<NSString>]
    ) -> [String] {
        guard contact.isKeyAvailable(key) else { return [] }
        return values().compactMap { labeled in
            let text = (labeled.value as String).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }

    static func phoneNumbers(from contact: CNContact) -> [String] {
        guard contact.isKeyAvailable(CNContactPhoneNumbersKey) else { return [] }
        return contact.phoneNumbers.compactMap { labeled in
            let number = labeled.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return number.isEmpty ? nil : number
        }
    }

    static func postalAddresses(from contact: CNContact) -> [String] {
        guard contact.isKeyAvailable(CNContactPostalAddressesKey) else { return [] }
        let formatter = CNPostalAddressFormatter()
        return contact.postalAddresses.compactMap { labeled in
            let address = formatter.string(from: labeled.value)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return address.isEmpty ? nil : address
        }
    }

    static func socialProfiles(from contact: CNContact) -> [String] {
        guard contact.isKeyAvailable(CNContactSocialProfilesKey) else { return [] }
        return contact.socialProfiles.compactMap { labeled in
            let profile = labeled.value
            let parts = [profile.service, profile.username, profile.urlString]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }

    static func instantMessages(from contact: CNContact) -> [String] {
        guard contact.isKeyAvailable(CNContactInstantMessageAddressesKey) else { return [] }
        return contact.instantMessageAddresses.compactMap { labeled in
            let address = labeled.value
            let parts = [address.service, address.username]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }

    static func dates(from contact: CNContact) -> [String] {
        guard contact.isKeyAvailable(CNContactDatesKey) else { return [] }
        return contact.dates.compactMap { labeled in
            let text = formatted(components: labeled.value as DateComponents)
            return text.isEmpty ? nil : text
        }
    }

    static func birthdayDescription(from contact: CNContact) -> String {
        guard contact.isKeyAvailable(CNContactBirthdayKey), let birthday = contact.birthday else {
            return ""
        }
        return formatted(components: birthday)
    }

    static func formatted(components: DateComponents) -> String {
        var parts: [String] = []
        if let year = components.year {
            parts.append(String(year))
        }
        if let month = components.month {
            parts.append(String(format: "%02d", month))
        }
        if let day = components.day {
            parts.append(String(format: "%02d", day))
        }
        return parts.joined(separator: "-")
    }
}
