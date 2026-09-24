import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: ScreenshotHistoryStore
    @State private var hoveredID: UUID?
    @State private var selectedItem: ScreenshotHistoryItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !historyStore.items.isEmpty {
                    Button("Clear All", role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) { historyStore.clearAll() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if historyStore.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 10) {
                        ForEach(historyStore.items) { item in
                            thumbnail(for: item)
                        }
                    }
                    .padding(14)
                }
                .frame(maxHeight: 300)
            }
        }
        .sheet(item: $selectedItem) { item in
            if let image = historyStore.image(for: item) {
                ScreenshotResultView(screenshot: CapturedScreenshot(id: item.id, image: image, mode: .fullScreen, capturedAt: item.capturedAt), isEmbedded: true)
                    .frame(width: 480, height: 420)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No screenshots yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func thumbnail(for item: ScreenshotHistoryItem) -> some View {
        let image = historyStore.image(for: item)
        return ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 84, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary).frame(width: 84, height: 64)
            }

            if hoveredID == item.id {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.45))
                    .frame(width: 84, height: 64)
                    .overlay(hoverActions(for: item))
                    .transition(.opacity)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.08), lineWidth: 1))
        .scaleEffect(hoveredID == item.id ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hoveredID)
        .onHover { hovering in hoveredID = hovering ? item.id : nil }
        .onTapGesture { selectedItem = item }
    }

    private func hoverActions(for item: ScreenshotHistoryItem) -> some View {
        HStack(spacing: 6) {
            Button {
                if let image = historyStore.image(for: item) { ClipboardManager.copy(image) }
            } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 10))
            }
            Button {
                withAnimation { historyStore.delete(item) }
            } label: {
                Image(systemName: "trash").font(.system(size: 10))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}
