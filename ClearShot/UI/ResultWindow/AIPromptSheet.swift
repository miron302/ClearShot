import SwiftUI

struct AIPromptSheet: View {
    enum Mode {
        case analyze
        case edit

        var title: String {
            switch self {
            case .analyze: return "Ask AI"
            case .edit: return "Edit with AI"
            }
        }
        var placeholder: String {
            switch self {
            case .analyze: return "e.g. Summarize this screenshot"
            case .edit: return "e.g. Remove the background and make it black and white"
            }
        }
        var confirmTitle: String {
            switch self {
            case .analyze: return "Ask"
            case .edit: return "Generate"
            }
        }
        var suggestions: [String] {
            switch self {
            case .analyze:
                return ["Explain what's in this screenshot", "Extract the text from this screenshot", "Summarize this screenshot", "What am I looking at?"]
            case .edit:
                return ["Blur any sensitive information", "Convert to black and white", "Add a soft drop shadow", "Crop tightly around the main content"]
            }
        }
    }

    let mode: Mode
    let providerName: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(mode.title, systemImage: mode == .analyze ? "sparkles" : "wand.and.stars")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(providerName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.gray.opacity(0.15), in: Capsule())
            }

            TextField(mode.placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .lineLimit(3...6)
                .onSubmit(submit)

            VStack(alignment: .leading, spacing: 6) {
                Text("Suggestions").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                WrapChips(items: mode.suggestions) { picked in
                    text = picked
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(mode.confirmTitle, action: submit)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { appeared = true } }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }
}

/// Simple flow-layout of tappable suggestion chips.
private struct WrapChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Button(item) { onTap(item) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.12), in: Capsule())
            }
        }
    }
}

/// Minimal custom Layout that wraps chips onto multiple lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 380
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
