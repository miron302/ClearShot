import SwiftUI
import Combine

/// A tiny pub/sub bridge so deeply-nested, non-view code (capture services,
/// AI providers) can surface a human-readable error without needing a
/// reference to whatever window happens to be on screen.
@MainActor
final class ErrorPresenter: ObservableObject {
    static let shared = ErrorPresenter()
    private init() {}

    @Published var currentMessage: PresentedError?

    struct PresentedError: Identifiable {
        let id = UUID()
        let title: String
        let detail: String?
    }

    func present(_ error: Error) {
        if let localized = error as? LocalizedError {
            currentMessage = PresentedError(
                title: localized.errorDescription ?? "Something went wrong.",
                detail: localized.recoverySuggestion
            )
        } else {
            currentMessage = PresentedError(title: error.localizedDescription, detail: nil)
        }
        ToastWindowController.shared.showError(currentMessage!)
    }

    func dismiss() {
        currentMessage = nil
    }
}
