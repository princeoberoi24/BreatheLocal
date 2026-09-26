//
//  StagingControls.swift
//  BreatheLocal
//

import SwiftUI

struct StagingStateIndicator: View {
    let isStaged: Bool

    var body: some View {
        Label(
            isStaged ? "Staged for Deletion" : "Keep",
            systemImage: isStaged ? "trash.circle.fill" : "checkmark.circle.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(isStaged ? Color.red : Color.sageGreen)
    }
}

struct KeepDeleteActions: View {
    let isStaged: Bool
    let onKeep: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button("Keep", action: onKeep)
                .buttonStyle(.bordered)
                .tint(.sageGreen)
            Button("Delete", action: onDelete)
                .buttonStyle(.bordered)
                .tint(.red)
        }
        .controlSize(.small)
    }
}

struct StagingRowBackground: ViewModifier {
    let isStaged: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isStaged ? Color.red.opacity(0.45) : Color.sageGreen.opacity(0.4),
                        lineWidth: 1.5
                    )
            )
    }
}

struct StagingSummaryBar: View {
    let count: Int
    var detail: String? = nil

    var body: some View {
        HStack {
            Image(systemName: count == 0 ? "checkmark.circle.fill" : "trash.circle.fill")
                .foregroundStyle(count == 0 ? Color.sageGreen : Color.red)
            Text(count == 0 ? "No items staged for deletion" : "\(count) staged for deletion")
                .font(.subheadline.weight(.medium))
            if let detail, count > 0 {
                Spacer()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.bar)
    }
}

extension View {
    func stagingChrome(isStaged: Bool) -> some View {
        modifier(StagingRowBackground(isStaged: isStaged))
    }
}
