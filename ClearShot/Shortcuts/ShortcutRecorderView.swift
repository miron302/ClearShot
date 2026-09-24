import SwiftUI
import AppKit

/// A small NSView-backed control that captures the next key combination the
/// user presses and reports it back as a `KeyboardShortcutSpec`.
struct ShortcutRecorderView: View {
    @Binding var shortcut: KeyboardShortcutSpec
    var onChanged: (() -> Void)?

    @State private var isRecording = false

    var body: some View {
        Button {
            isRecording = true
        } label: {
            HStack(spacing: 6) {
                Text(isRecording ? "Press keys…" : shortcut.displayString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(isRecording ? .secondary : .primary)
                if isRecording {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(minWidth: 110)
            .background(RoundedRectangle(cornerRadius: 6).fill(isRecording ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isRecording ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .background(
            RecorderCapture(isRecording: $isRecording) { newSpec in
                shortcut = newSpec
                onChanged?()
            }
        )
        .animation(.easeInOut(duration: 0.15), value: isRecording)
    }
}

private struct RecorderCapture: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (KeyboardShortcutSpec) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onCapture = { spec in
            onCapture(spec)
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.isArmed = isRecording
        if isRecording { DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) } }
    }

    final class CaptureView: NSView {
        var isArmed = false
        var onCapture: ((KeyboardShortcutSpec) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard isArmed else { super.keyDown(with: event); return }

            var mods: KeyboardShortcutSpec.Modifiers = []
            if event.modifierFlags.contains(.command) { mods.insert(.command) }
            if event.modifierFlags.contains(.shift) { mods.insert(.shift) }
            if event.modifierFlags.contains(.option) { mods.insert(.option) }
            if event.modifierFlags.contains(.control) { mods.insert(.control) }

            guard !mods.isEmpty else { return } // require at least one modifier to avoid accidental captures
            onCapture?(KeyboardShortcutSpec(keyCode: UInt32(event.keyCode), modifiers: mods))
        }
    }
}
