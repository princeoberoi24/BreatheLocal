//
//  LargeVideosView.swift
//  BreatheLocal
//

import SwiftUI

struct LargeVideosView: View {
    @Environment(StorageViewModel.self) private var viewModel
    @State private var isReviewPresented = false

    private let symbolName = "video.square.fill"

    var body: some View {
        Group {
            if let accessError = viewModel.photoAccessError {
                photoAccessUnavailableView(for: accessError)
            } else if viewModel.largeVideos.isEmpty {
                EmptyBreathingStateView()
            } else {
                List(viewModel.largeVideos) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            AssetThumbnailView(
                                localIdentifier: item.id,
                                placeholderSymbol: symbolName,
                                isVideo: true
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.displayName)
                                    .foregroundStyle(.primary)
                                Text(item.byteSizeDisplay)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                StagingStateIndicator(isStaged: item.isMarkedForDeletion)
                            }
                            Spacer()
                        }
                        KeepDeleteActions(isStaged: item.isMarkedForDeletion) {
                            viewModel.markVideo(id: item.id, stagedForDeletion: false)
                        } onDelete: {
                            viewModel.markVideo(id: item.id, stagedForDeletion: true)
                        }
                    }
                    .stagingChrome(isStaged: item.isMarkedForDeletion)
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Large Videos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Review") {
                    isReviewPresented = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.photoAccessError == nil, !viewModel.largeVideos.isEmpty {
                StagingSummaryBar(
                    count: viewModel.stagedVideoCount,
                    detail: viewModel.fileSizeDisplay(
                        viewModel.largeVideos.filter(\.isMarkedForDeletion).reduce(Int64(0)) { $0 + $1.byteSize }
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
                description: Text("BreatheLocal cannot rank large videos without permission. Enable Photos access in Settings, then scan again.")
            )
        case .restricted:
            ContentUnavailableView(
                "Photos Access Restricted",
                systemImage: symbolName,
                description: Text("This device restricts Photos access, so local videos cannot be measured.")
            )
        case .fetchFailed:
            ContentUnavailableView(
                "Couldn't Read Videos",
                systemImage: symbolName,
                description: Text("The camera roll could not be queried. Try scanning again.")
            )
        }
    }
}

#Preview {
    NavigationStack {
        LargeVideosView()
    }
    .environment(StorageViewModel())
    .tint(.sageGreen)
}
