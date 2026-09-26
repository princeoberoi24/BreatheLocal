//
//  ScreenshotsView.swift
//  BreatheLocal
//

import SwiftUI

struct ScreenshotsView: View {
    @Environment(StorageViewModel.self) private var viewModel
    @State private var isReviewPresented = false

    private let symbolName = "camera.viewfinder"

    var body: some View {
        Group {
            if let accessError = viewModel.photoAccessError {
                photoAccessUnavailableView(for: accessError)
            } else if viewModel.screenshots.isEmpty {
                EmptyBreathingStateView()
            } else {
                List(viewModel.screenshots) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            AssetThumbnailView(
                                localIdentifier: item.id,
                                placeholderSymbol: symbolName
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
                            viewModel.markScreenshot(id: item.id, stagedForDeletion: false)
                        } onDelete: {
                            viewModel.markScreenshot(id: item.id, stagedForDeletion: true)
                        }
                    }
                    .stagingChrome(isStaged: item.isMarkedForDeletion)
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Screenshots")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Review") {
                    isReviewPresented = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.photoAccessError == nil, !viewModel.screenshots.isEmpty {
                StagingSummaryBar(
                    count: viewModel.stagedScreenshotCount,
                    detail: viewModel.fileSizeDisplay(
                        viewModel.screenshots.filter(\.isMarkedForDeletion).reduce(Int64(0)) { $0 + $1.byteSize }
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
                description: Text("BreatheLocal cannot list screenshots without permission. Enable Photos access in Settings, then scan again.")
            )
        case .restricted:
            ContentUnavailableView(
                "Photos Access Restricted",
                systemImage: symbolName,
                description: Text("This device restricts Photos access, so screenshots cannot be measured.")
            )
        case .fetchFailed:
            ContentUnavailableView(
                "Couldn't Read Screenshots",
                systemImage: symbolName,
                description: Text("Screenshot assets could not be queried. Try scanning again.")
            )
        }
    }
}

#Preview {
    NavigationStack {
        ScreenshotsView()
    }
    .environment(StorageViewModel())
    .tint(.sageGreen)
}
