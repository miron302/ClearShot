import AppKit
import SwiftUI

/// Owns one borderless, screen-filling window per display and lets the user
/// drag out a rectangle. Escape cancels. Calls `completion` exactly once.
final class RegionSelectionWindowController {
    private var windows: [NSWindow] = []
    private let completion: (NSImage?, CGRect) -> Void
    private var finished = false

    init(completion: @escaping (NSImage?, CGRect) -> Void) {
        self.completion = completion
    }

    func show() {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true

            let overlay = RegionOverlayView(
                onFinish: { [weak self] rect in self?.finish(rect: rect, screen: screen) },
                onCancel: { [weak self] in self?.cancel() }
            )
            window.contentView = NSHostingView(rootView: overlay)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSCursor.crosshair.set()
        windows.first?.makeKey()
    }

    private func finish(rect: CGRect, screen: NSScreen) {
        guard !finished else { return }
        finished = true
        NSCursor.arrow.set()

        // Convert from the overlay's flipped view coordinates into global
        // display coordinates expected by CGWindowListCreateImage.
        let globalRect = CGRect(
            x: screen.frame.origin.x + rect.origin.x,
            y: screen.frame.origin.y + rect.origin.y,
            width: rect.width,
            height: rect.height
        )
        let flippedY = (NSScreen.screens.map { $0.frame.maxY }.max() ?? screen.frame.maxY) - globalRect.maxY
        let captureRect = CGRect(x: globalRect.origin.x, y: flippedY, width: globalRect.width, height: globalRect.height)

        closeAll()

        Task { @MainActor in
            do {
                let shot = try await ScreenCaptureService.shared.captureRegion(captureRect)
                completion(shot.image, captureRect)
            } catch {
                ErrorPresenter.shared.present(error)
                completion(nil, .zero)
            }
        }
    }

    private func cancel() {
        guard !finished else { return }
        finished = true
        NSCursor.arrow.set()
        closeAll()
        completion(nil, .zero)
    }

    private func closeAll() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

/// The interactive drag-selection surface, one instance per screen.
private struct RegionOverlayView: View {
    let onFinish: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var pulse = false

    private var selectionRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(pulse ? 0.28 : 0.22)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            if let rect = selectionRect {
                // "Hole punch" effect: darken everything except the selection.
                Rectangle()
                    .fill(Color.white.opacity(0.001)) // hit-test transparent, keeps blend group
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                            .background(Color.clear)
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .blendMode(.destinationOut)

                dimensionLabel(for: rect)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "crop")
                        .font(.system(size: 22, weight: .medium))
                    Text("Click and drag to select a region · Esc to cancel")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.opacity)
            }
        }
        .compositingGroup()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    if dragStart == nil { dragStart = value.startLocation }
                    dragCurrent = value.location
                }
                .onEnded { value in
                    guard let rect = selectionRect, rect.width > 3, rect.height > 3 else {
                        onCancel()
                        return
                    }
                    onFinish(rect)
                }
        )
        .background(KeyCatcher(onEscape: onCancel))
        .ignoresSafeArea()
    }

    private func dimensionLabel(for rect: CGRect) -> some View {
        Text("\(Int(rect.width)) × \(Int(rect.height))")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.7), in: Capsule())
            .foregroundStyle(.white)
            .position(x: rect.midX, y: max(rect.minY - 16, 12))
            .animation(.easeOut(duration: 0.1), value: rect)
    }
}

/// Bridges Esc-key handling into SwiftUI without needing a full NSViewRepresentable gesture stack.
private struct KeyCatcher: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = EscKeyView()
        view.onEscape = onEscape
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class EscKeyView: NSView {
        var onEscape: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
        }
    }
}
