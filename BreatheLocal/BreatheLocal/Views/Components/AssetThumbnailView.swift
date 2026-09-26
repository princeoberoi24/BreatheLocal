//
//  AssetThumbnailView.swift
//  BreatheLocal
//

import Photos
import SwiftUI
import UIKit

struct AssetThumbnailView: View {
    let localIdentifier: String
    var placeholderSymbol: String = "photo"
    var isVideo: Bool = false

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    private static let manager = PHCachingImageManager()
    private static let thumbnailSize = CGSize(width: 160, height: 160)

    var body: some View {
        ZStack {
            Color.sageGreenMuted
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.body)
                    .foregroundStyle(Color.sageGreen)
            }
            if isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: localIdentifier) {
            await requestThumbnail()
        }
        .onDisappear {
            cancelRequest()
        }
    }

    private func requestThumbnail() async {
        cancelRequest()
        image = nil
        let identifier = localIdentifier
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        requestID = Self.manager.requestImage(
            for: asset,
            targetSize: Self.thumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            Task { @MainActor in
                guard identifier == localIdentifier else { return }
                if let result {
                    image = result
                }
            }
        }
    }

    private func cancelRequest() {
        if let requestID {
            Self.manager.cancelImageRequest(requestID)
            self.requestID = nil
        }
    }
}
