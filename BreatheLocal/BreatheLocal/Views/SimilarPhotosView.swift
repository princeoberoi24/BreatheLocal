//
//  SimilarPhotosView.swift
//  BreatheLocal
//

import SwiftUI

struct SimilarPhotosView: View {
    @Environment(StorageViewModel.self) private var viewModel
    @State private var isReviewPresented = false

    private let symbolName = "square.on.square.squareshape.controlhandles"

    var body: some View {
        Group {
            if let accessError = viewModel.photoAccessError {
                photoAccessUnavailableView(for: accessError)
            } else if viewModel.similarPhotos.isEmpty {
                EmptyBreathingStateView()
            } else {
                List(viewModel.similarPhotos) { group in
                    Section {
                        ForEach(group.members) { member in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    AssetThumbnailView(
                                        localIdentifier: member.id,
                                        placeholderSymbol: symbolName
                                    )
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.displayName)
                                            .foregroundStyle(.primary)
                                        Text(member.byteSizeDisplay)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        StagingStateIndicator(isStaged: member.isMarkedForDeletion)
                                    }
                                    Spacer()
                                }
                                KeepDeleteActions(isStaged: member.isMarkedForDeletion) {
                                    viewModel.markSimilarPhoto(
                                        groupID: group.id,
                                        memberID: member.id,
                                        stagedForDeletion: false
                                    )
                                } onDelete: {
                                    viewModel.markSimilarPhoto(
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
                        Text("\(group.deletionCount) staged for deletion · \(viewModel.fileSizeDisplay(group.reclaimableBytes)) recoverable")
                    }
                }
            }
        }
        .navigationTitle("Similar Photos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Review") {
                    isReviewPresented = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.photoAccessError == nil, !viewModel.similarPhotos.isEmpty {
                StagingSummaryBar(
                    count: viewModel.similarPhotos.reduce(0) { $0 + $1.deletionCount },
                    detail: viewModel.fileSizeDisplay(
                        viewModel.similarPhotos.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
                    )
                )
            }
        }
        .sheet(isPresented: $isReviewPresented) {
            ReviewSheetView()
                .environment(viewModel)
        }
    }

    @ViewBuilder
    private func photoAccessUnavailableView(for error: PhotoAccessError) -> some View {
        switch error {
        case .denied:
            ContentUnavailableView(
                "Photos Access Denied",
                systemImage: symbolName,
                description: Text("BreatheLocal cannot group similar photos without permission. Enable Photos access in Settings, then scan again.")
            )
        case .restricted:
            ContentUnavailableView(
                "Photos Access Restricted",
                systemImage: symbolName,
                description: Text("This device restricts Photos access, so similar photos cannot be grouped.")
            )
        case .fetchFailed:
            ContentUnavailableView(
                "Couldn't Read Photos",
                systemImage: symbolName,
                description: Text("Recent photos could not be queried. Try scanning again.")
            )
        }
    }
}

#Preview {
    NavigationStack {
        SimilarPhotosView()
    }
    .environment(StorageViewModel())
    .tint(.sageGreen)
}
