//
//  DuplicateContactsView.swift
//  BreatheLocal
//

import SwiftUI

struct DuplicateContactsView: View {
    @Environment(StorageViewModel.self) private var viewModel
    @State private var isReviewPresented = false

    private let symbolName = "person.2.wave.2.fill"

    var body: some View {
        Group {
            if let accessError = viewModel.contactAccessError {
                contactAccessUnavailableView(for: accessError)
            } else if viewModel.duplicateContacts.isEmpty {
                EmptyBreathingStateView()
            } else {
                List(viewModel.duplicateContacts) { group in
                    Section {
                        ForEach(group.members) { member in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: member.isMarkedForDeletion ? "trash.circle.fill" : "checkmark.shield.fill")
                                        .font(.title2)
                                        .foregroundStyle(member.isMarkedForDeletion ? Color.red : Color.sageGreen)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.formattedName)
                                        Text(member.phoneNumbers.first ?? member.emailAddresses.first ?? "No contact details")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        StagingStateIndicator(isStaged: member.isMarkedForDeletion)
                                    }
                                    Spacer()
                                }
                                KeepDeleteActions(isStaged: member.isMarkedForDeletion) {
                                    viewModel.markContact(
                                        groupID: group.id,
                                        memberID: member.id,
                                        stagedForDeletion: false
                                    )
                                } onDelete: {
                                    viewModel.markContact(
                                        groupID: group.id,
                                        memberID: member.id,
                                        stagedForDeletion: true
                                    )
                                }
                            }
                            .stagingChrome(isStaged: member.isMarkedForDeletion)
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text(group.displayName)
                    } footer: {
                        Text("\(group.deletionCount) staged for deletion")
                    }
                }
            }
        }
        .navigationTitle("Duplicate Contacts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Review") {
                    isReviewPresented = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.contactAccessError == nil, !viewModel.duplicateContacts.isEmpty {
                StagingSummaryBar(count: viewModel.stagedContactCount)
            }
        }
        .sheet(isPresented: $isReviewPresented) {
            ReviewSheetView()
                .environment(viewModel)
        }
    }

    @ViewBuilder
    private func contactAccessUnavailableView(for error: ContactAccessError) -> some View {
        switch error {
        case .denied:
            ContentUnavailableView(
                "Contacts Access Denied",
                systemImage: symbolName,
                description: Text("BreatheLocal cannot find duplicate contacts without permission. Enable Contacts access in Settings, then scan again.")
            )
        case .restricted:
            ContentUnavailableView(
                "Contacts Access Restricted",
                systemImage: symbolName,
                description: Text("This device restricts Contacts access, so duplicate records cannot be grouped.")
            )
        case .fetchFailed, .saveFailed:
            ContentUnavailableView(
                "Couldn't Read Contacts",
                systemImage: symbolName,
                description: Text("The device contact database could not be parsed. Try scanning again.")
            )
        }
    }
}

#Preview {
    NavigationStack {
        DuplicateContactsView()
    }
    .environment(StorageViewModel())
    .tint(.sageGreen)
}
