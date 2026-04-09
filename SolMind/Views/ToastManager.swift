import SwiftUI

// MARK: - Toast Notification Manager
//
// Lightweight @MainActor singleton for transient status banners.
// Usage from any context:
//   await MainActor.run { ToastManager.shared.success("Done!") }
// Usage from MainActor views/VMs:
//   ToastManager.shared.error("Something went wrong")

@Observable
@MainActor
final class ToastManager {
    static let shared = ToastManager()
    private init() {}

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let style: Style

        enum Style {
            case success, error, info, warning

            var icon: String {
                switch self {
                case .success: return "checkmark.circle.fill"
                case .error:   return "xmark.circle.fill"
                case .info:    return "info.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                }
            }

            var color: Color {
                switch self {
                case .success: return .green
                case .error:   return .red
                case .info:    return .blue
                case .warning: return .orange
                }
            }
        }
    }

    private(set) var current: Toast?

    func show(_ message: String, style: Toast.Style = .info, duration: TimeInterval = 3) {
        current = Toast(message: message, style: style)
        let id = current!.id
        Task {
            try? await Task.sleep(for: .seconds(duration))
            if current?.id == id { current = nil }
        }
    }

    func success(_ message: String, duration: TimeInterval = 3)  { show(message, style: .success, duration: duration) }
    func error(_ message: String, duration: TimeInterval = 5)    { show(message, style: .error,   duration: duration) }
    func info(_ message: String, duration: TimeInterval = 2.5)   { show(message, style: .info,    duration: duration) }
    func warning(_ message: String, duration: TimeInterval = 4)  { show(message, style: .warning, duration: duration) }

    func dismiss() { current = nil }
}

// MARK: - Toast Banner View

struct ToastBanner: View {
    let toast: ToastManager.Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.style.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(toast.style.color)
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 380)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        .padding(.horizontal, 20)
        .contentShape(Capsule())
        .onTapGesture { ToastManager.shared.dismiss() }
    }
}

// MARK: - View Modifier

private struct ToastOverlayModifier: ViewModifier {
    @State private var manager = ToastManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = manager.current {
                    ToastBanner(toast: toast)
                        .padding(.bottom, 20)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .id(toast.id)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.current?.id)
    }
}

extension View {
    /// Attaches the global toast notification overlay to this view.
    func toastOverlay() -> some View {
        modifier(ToastOverlayModifier())
    }
}
