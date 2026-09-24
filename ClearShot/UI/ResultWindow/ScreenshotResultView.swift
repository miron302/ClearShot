import SwiftUI
import AppKit

struct ScreenshotResultView: View {
    let screenshot: CapturedScreenshot
    var isEmbedded: Bool = false
    var onClose: (() -> Void)? = nil

    @EnvironmentObject private var providerManager: AIProviderManager
    @EnvironmentObject private var appSettings: AppSettings

    @State private var currentImage: NSImage
    @State private var buttonsAppeared = false
    @State private var extractedText: String?
    @State private var aiResponseText: String?
    @State private var isRunningOCR = false
    @State private var isSendingToAI = false
    @State private var isEditingWithAI = false
    @State private var showPromptSheet = false
    @State private var promptSheetMode: PromptSheetMode = .askAI
    @State private var copiedFeedback = false
    @State private var showDeleteConfirm = false
    @State private var isDeleted = false

    enum PromptSheetMode { case askAI, editWithAI }

    init(screenshot: CapturedScreenshot, isEmbedded: Bool = false, onClose: (() -> Void)? = nil) {
        self.screenshot = screenshot
        self.isEmbedded = isEmbedded
        self.onClose = onClose
        _currentImage = State(initialValue: screenshot.image)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            preview
                .padding(.horizontal, 16)
                .padding(.top, 10)

            if let extractedText {
                textPanel(title: "Extracted Text", text: extractedText, systemImage: "text.viewfinder") {
                    withAnimation { self.extractedText = nil }
                }
            }
            if let aiResponseText {
                textPanel(title: "\(activeProviderName) Response", text: aiResponseText, systemImage: "sparkles") {
                    withAnimation { self.aiResponseText = nil }
                }
            }

            actionGrid
                .padding(16)
        }
        .frame(width: isEmbedded ? nil : 460)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: isEmbedded ? 0 : 16))
        .overlay(
            RoundedRectangle(cornerRadius: isEmbedded ? 0 : 16)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .opacity(isDeleted ? 0 : 1)
        .scaleEffect(isDeleted ? 0.9 : 1)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05)) {
                buttonsAppeared = true
            }
        }
        .sheet(isPresented: $showPromptSheet) {
            AIPromptSheet(
                mode: promptSheetMode == .askAI ? .analyze : .edit,
                providerName: activeProviderName
            ) { prompt in
                showPromptSheet = false
                if promptSheetMode == .askAI {
                    runAIAnalysis(prompt: prompt)
                } else {
                    runAIEdit(instruction: prompt)
                }
            }
        }
        .alert("Delete this screenshot?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteScreenshot() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label(screenshot.mode.displayName, systemImage: screenshot.mode.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(screenshot.capturedAt.relativeDescription)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            if !isEmbedded {
                IconOnlyButton(icon: "xmark", tint: .secondary) { onClose?() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            if isSendingToAI || isEditingWithAI {
                RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.25))
                ProgressView().controlSize(.large)
            }
            Image(nsImage: currentImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(isSendingToAI || isEditingWithAI ? 0.4 : 1)
        }
        .background(Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animatedIfEnabled(.easeInOut(duration: 0.2), value: isSendingToAI || isEditingWithAI)
    }

    // MARK: - Text panels (OCR / AI response)

    private func textPanel(title: String, text: String, systemImage: String, onDismiss: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    ClipboardManager.copy(text: text)
                    flashCopiedFeedback()
                } label: {
                    Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
            ScrollView {
                Text(text)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 90)
        }
        .padding(10)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
    }

    // MARK: - Actions

    private var actionGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 8) {
            actionCell(icon: "sparkles", label: "Ask AI", index: 0) {
                promptSheetMode = .askAI
                showPromptSheet = true
            }
            actionCell(icon: "doc.on.doc", label: "Copy", index: 1) {
                ClipboardManager.copy(currentImage)
                flashCopiedFeedback()
            }
            actionCell(icon: "square.and.arrow.down", label: "Save To…", index: 2) {
                try? ImageFileWriter.presentSavePanel(for: currentImage, suggestedName: screenshot.suggestedFileName)
            }
            actionCell(icon: "pencil.tip.crop.circle", label: "Edit", index: 3) {
                openInMarkup()
            }
            actionCell(icon: "wand.and.stars", label: "Edit with AI", index: 4) {
                promptSheetMode = .editWithAI
                showPromptSheet = true
            }
            actionCell(icon: "square.and.arrow.up", label: "Share", index: 5) {
                presentShareSheet()
            }
            actionCell(icon: "app.badge", label: "Open With…", index: 6) {
                presentOpenWith()
            }
            actionCell(icon: "text.viewfinder", label: "Extract Text", index: 7, isLoading: isRunningOCR) {
                runOCR()
            }
            actionCell(icon: "ellipsis.circle", label: "More", index: 8) {
                presentMoreMenu()
            }
        }
    }

    private func actionCell(icon: String, label: String, index: Int, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        ActionButton(icon: icon, label: label, isProminent: index == 0, isLoading: isLoading, action: action)
            .opacity(buttonsAppeared ? 1 : 0)
            .offset(y: buttonsAppeared ? 0 : 8)
            .animation(
                AppSettings.shared.animationsEnabled
                    ? .spring(response: 0.4, dampingFraction: 0.75).delay(Double(index) * 0.03)
                    : nil,
                value: buttonsAppeared
            )
    }

    // MARK: - Action implementations

    private var activeProviderName: String {
        providerManager.activeProviderID.displayName
    }

    private func flashCopiedFeedback() {
        withAnimation(.easeInOut(duration: 0.15)) { copiedFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { copiedFeedback = false }
        }
    }

    private func runOCR() {
        isRunningOCR = true
        Task {
            do {
                let text = try await TextRecognizer.recognizeText(in: currentImage)
                await MainActor.run {
                    isRunningOCR = false
                    withAnimation { extractedText = text.isEmpty ? "No text was found in this screenshot." : text }
                }
            } catch {
                await MainActor.run {
                    isRunningOCR = false
                    ErrorPresenter.shared.present(error)
                }
            }
        }
    }

    private func runAIAnalysis(prompt: String) {
        guard let provider = providerManager.activeProvider else {
            ErrorPresenter.shared.present(AIError.providerUnavailable)
            return
        }
        isSendingToAI = true
        let model = providerManager.modelBinding(for: provider.id)
        Task {
            do {
                let result = try await provider.analyze(AIAnalysisRequest(image: currentImage, prompt: prompt), model: model)
                await MainActor.run {
                    isSendingToAI = false
                    withAnimation { aiResponseText = result }
                }
            } catch {
                await MainActor.run {
                    isSendingToAI = false
                    ErrorPresenter.shared.present(error)
                }
            }
        }
    }

    private func runAIEdit(instruction: String) {
        guard let provider = providerManager.activeProvider else {
            ErrorPresenter.shared.present(AIError.providerUnavailable)
            return
        }
        guard provider.supportsImageEditing else {
            ErrorPresenter.shared.present(AIError.editingNotSupported)
            return
        }
        isEditingWithAI = true
        let model = providerManager.modelBinding(for: provider.id)
        Task {
            do {
                let newImage = try await provider.edit(AIEditRequest(image: currentImage, instruction: instruction), model: model)
                await MainActor.run {
                    isEditingWithAI = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { currentImage = newImage }
                }
            } catch {
                await MainActor.run {
                    isEditingWithAI = false
                    ErrorPresenter.shared.present(error)
                }
            }
        }
    }

    private func openInMarkup() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        guard let data = currentImage.pngRepresentation else { return }
        try? data.write(to: tempURL)
        NSWorkspace.shared.open(tempURL)
    }

    private func presentShareSheet() {
        guard let window = NSApp.keyWindow, let contentView = window.contentView else { return }
        let picker = NSSharingServicePicker(items: [currentImage])
        picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
    }

    private func presentOpenWith() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        guard let data = currentImage.pngRepresentation else { return }
        try? data.write(to: tempURL)
        NSWorkspace.shared.open([tempURL], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"), configuration: .init(), completionHandler: nil)
    }

    private func presentMoreMenu() {
        let menu = NSMenu()

        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(MenuActionTarget.reveal(_:)), keyEquivalent: "")
        revealItem.target = MenuActionTarget.shared
        revealItem.representedObject = screenshot.id
        menu.addItem(revealItem)

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(MenuActionTarget.delete(_:)), keyEquivalent: "")
        deleteItem.target = MenuActionTarget.shared
        deleteItem.representedObject = screenshot.id
        menu.addItem(deleteItem)

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }

    private func deleteScreenshot() {
        withAnimation(.easeInOut(duration: 0.18)) { isDeleted = true }
        if let item = ScreenshotHistoryStore.shared.items.first(where: { $0.id == screenshot.id }) {
            ScreenshotHistoryStore.shared.delete(item)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onClose?() }
    }
}

/// Bridges a couple of NSMenu actions (which need an `@objc` target) back
/// into the app's normal Swift/history code.
final class MenuActionTarget: NSObject {
    static let shared = MenuActionTarget()

    @MainActor @objc func delete(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = ScreenshotHistoryStore.shared.items.first(where: { $0.id == id }) else { return }
        ScreenshotHistoryStore.shared.delete(item)
    }

    @MainActor @objc func reveal(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = ScreenshotHistoryStore.shared.items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([ScreenshotHistoryStore.shared.fileURL(for: item)])
    }
}
