import AppKit
import SwiftUI

extension View {
    /// Applies the user's Appearance setting as a `.preferredColorScheme`.
    func appAppearance(_ appearance: AppAppearance) -> some View {
        self.preferredColorScheme(appearance.colorScheme)
    }

    /// Convenience for conditionally applying an animation based on the
    /// user's "Animation preferences" toggle in Settings → Appearance.
    @ViewBuilder
    func animatedIfEnabled<V: Equatable>(_ animation: Animation, value: V) -> some View {
        if AppSettings.shared.animationsEnabled {
            self.animation(animation, value: value)
        } else {
            self
        }
    }
}

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension NSImage {
    /// Resizes for thumbnail display without mutating the original.
    func resized(to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
