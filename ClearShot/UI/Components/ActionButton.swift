import SwiftUI

/// The pill/icon buttons in the screenshot result UI (Copy, Save, Edit,
/// Ask AI, etc). Supports a compact icon-only style and a labeled style.
struct ActionButton: View {
    let icon: String
    let label: String
    var tint: Color = .primary
    var isProminent: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isProminent ? .white : tint)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { isHovering = hovering }
        }
    }

    @ViewBuilder
    private var background: some View {
        if isProminent {
            LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.85)], startPoint: .top, endPoint: .bottom)
        } else {
            (isHovering ? Color.gray.opacity(0.18) : Color.gray.opacity(0.1))
        }
    }
}

/// Compact, icon-only variant for dense toolbars.
struct IconOnlyButton: View {
    let icon: String
    var tint: Color = .primary
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(isHovering ? Color.gray.opacity(0.18) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.08 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { isHovering = hovering }
        }
    }
}
