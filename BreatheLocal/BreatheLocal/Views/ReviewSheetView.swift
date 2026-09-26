//
//  ReviewSheetView.swift
//  BreatheLocal
//

import SwiftUI

struct ReviewSheetView: View {
    @Environment(StorageViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirming = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.pendingDeletionCount == 0 {
                    ContentUnavailableView(
                        "Nothing to Review",
                        systemImage: "shield.checkerboard",
                        description: Text("Mark photos, videos, screenshots, or duplicate contacts for deletion, then review them here.")
                    )
                } else {
                    List {
                        if !viewModel.pendingMediaIdentifiers.isEmpty {
                            Section("Media") {
                                ForEach(pendingMediaItems, id: \.id) { item in
                                    HStack(spacing: 12) {
                                        AssetThumbnailView(
                                            localIdentifier: item.id,
                                            placeholderSymbol: item.symbol,
                                            isVideo: item.isVideo
                                        )
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                            Text(item.size)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button("Keep") {
                                            viewModel.unstagePendingMedia(id: item.id)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.sageGreen)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }

                        if !viewModel.pendingContactIDs.isEmpty {
                            Section("Contacts") {
                                ForEach(pendingContactItems, id: \.id) { item in
                                    HStack {
                                        Label(item.name, systemImage: "person.2.wave.2.fill")
                                        Spacer()
                                        Button("Keep") {
                                            viewModel.unstagePendingContact(id: item.id)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.sageGreen)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(viewModel.isDeleting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete") {
                        isConfirming = true
                    }
                    .disabled(viewModel.pendingDeletionCount == 0 || viewModel.isDeleting)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.pendingDeletionCount > 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "shield.checkerboard")
                            .font(.title2)
                            .foregroundStyle(Color.sageGreen)
                        Text("\(viewModel.pendingDeletionCount) items · \(viewModel.pendingReclaimableDisplay)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let message = viewModel.deletionErrorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                        if viewModel.isDeleting {
                            ProgressView("Removing from this device…")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.bar)
                }
            }
            .confirmationDialog(
                "Permanently delete these items from this device?",
                isPresented: $isConfirming,
                titleVisibility: .visible
            ) {
                Button("Delete Permanently", role: .destructive) {
                    Task {
                        await viewModel.confirmPendingDeletions()
                        if viewModel.deletionErrorMessage == nil {
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes selected photos, screenshots, videos, and duplicate contacts from the device. This cannot be undone.")
            }
        }
    }

    private var pendingMediaItems: [(id: String, name: String, size: String, symbol: String, isVideo: Bool)] {
        let similar = viewModel.similarPhotos.flatMap { group in
            group.members.filter(\.isMarkedForDeletion).map {
                (id: $0.id, name: $0.displayName, size: $0.byteSizeDisplay, symbol: "square.on.square.squareshape.controlhandles", isVideo: false)
            }
        }
        let shots = viewModel.screenshots.filter(\.isMarkedForDeletion).map {
            (id: $0.id, name: $0.displayName, size: $0.byteSizeDisplay, symbol: "camera.viewfinder", isVideo: false)
        }
        let videos = viewModel.largeVideos.filter(\.isMarkedForDeletion).map {
            (id: $0.id, name: $0.displayName, size: $0.byteSizeDisplay, symbol: "video.square.fill", isVideo: true)
        }
        return similar + shots + videos
    }

    private var pendingContactItems: [(id: String, name: String)] {
        viewModel.duplicateContacts.flatMap { group in
            group.members.filter(\.isMarkedForDeletion).map {
                (id: $0.id, name: $0.formattedName)
            }
        }
    }
}

#Preview {
    ReviewSheetView()
        .environment(StorageViewModel())
        .tint(.sageGreen)
}
