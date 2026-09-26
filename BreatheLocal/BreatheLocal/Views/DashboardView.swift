//
//  DashboardView.swift
//  BreatheLocal
//

import SwiftUI

struct DashboardView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardHomeView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "leaf.fill")
            }

            NavigationStack {
                SimilarPhotosView()
            }
            .tabItem {
                Label("Similar", systemImage: "square.on.square.squareshape.controlhandles")
            }

            NavigationStack {
                ScreenshotsView()
            }
            .tabItem {
                Label("Screenshots", systemImage: "camera.viewfinder")
            }

            NavigationStack {
                LargeVideosView()
            }
            .tabItem {
                Label("Videos", systemImage: "video.square.fill")
            }

            NavigationStack {
                DuplicateContactsView()
            }
            .tabItem {
                Label("Contacts", systemImage: "person.2.wave.2.fill")
            }
        }
    }
}

private struct DashboardHomeView: View {
    @Environment(StorageViewModel.self) private var viewModel

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "wind")
                        .font(.title2)
                        .foregroundStyle(Color.sageGreen)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BreatheLocal")
                            .font(.headline)
                        Text(scanStatusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Device Storage") {
                LabeledContent("Used", value: viewModel.storageMetrics.usedDisplay)
                LabeledContent("Free", value: viewModel.storageMetrics.freeDisplay)
                LabeledContent("Total", value: viewModel.storageMetrics.totalDisplay)
            }
        }
        .navigationTitle("Dashboard")
        .task {
            await viewModel.refreshStorageMetrics()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Scan") {
                    Task {
                        await viewModel.startScan()
                    }
                }
                .disabled(viewModel.scanState == .scanning)
            }
        }
    }

    private var scanStatusText: String {
        switch viewModel.scanState {
        case .idle:
            return "Ready to scan"
        case .scanning:
            return "Scanning…"
        case .completed:
            return "Scan complete"
        }
    }

}

#Preview {
    DashboardView()
        .environment(StorageViewModel())
        .tint(.sageGreen)
}
