//
//  EmptyBreathingStateView.swift
//  BreatheLocal
//

import SwiftUI

struct EmptyBreathingStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Image(systemName: "wind.circle")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(Color.sageGreenMuted)
                Image(systemName: "wind")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(Color.sageGreen)
            }
            .symbolRenderingMode(.hierarchical)
            .accessibilityHidden(true)

            Text("Your storage is clear! Phone is breathing easy.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    EmptyBreathingStateView()
        .tint(.sageGreen)
}
