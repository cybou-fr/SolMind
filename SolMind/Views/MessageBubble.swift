import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Individual Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isLeading { Spacer(minLength: 48) }

            VStack(alignment: isLeading ? .trailing : .leading, spacing: 4) {
                if case .tool(let name) = message.role {
                    Text("🔧 \(name)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }

                bubbleContent
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleBackground)
                    .clipShape(bubbleShape)
                    .foregroundStyle(foregroundColor)
                    .contextMenu {
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = message.content
                            #elseif os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                            #endif
                        } label: {
                            Label("Copy Message", systemImage: "doc.on.doc")
                        }
                    }

                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !isLeading { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Private Helpers

    private var isLeading: Bool {
        switch message.role {
        case .user: return true
        default: return false
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.isStreaming {
            HStack(spacing: 4) {
                markdownText(message.content)
                TypingIndicator()
            }
        } else {
            markdownText(message.content)
                .textSelection(.enabled)
                .multilineTextAlignment(isLeading ? .trailing : .leading)
        }
    }

    @ViewBuilder
    private func markdownText(_ raw: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(raw)
        }
    }

    private var bubbleBackground: some ShapeStyle {
        switch message.role {
        case .user:
            return AnyShapeStyle(Color.accentColor)
        case .error:
            return AnyShapeStyle(Color.red.opacity(0.15))
        case .tool:
            return AnyShapeStyle(Color.secondary.opacity(0.15))
        default:
            return AnyShapeStyle(Color.secondary.opacity(0.2))
        }
    }

    private var foregroundColor: Color {
        switch message.role {
        case .user: return .white
        case .error: return .red
        default: return .primary
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        switch message.role {
        case .user:
            return UnevenRoundedRectangle(
                topLeadingRadius: 16, bottomLeadingRadius: 16,
                bottomTrailingRadius: 4, topTrailingRadius: 16
            )
        default:
            return UnevenRoundedRectangle(
                topLeadingRadius: 4, bottomLeadingRadius: 16,
                bottomTrailingRadius: 16, topTrailingRadius: 16
            )
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                phase = (phase + 1) % 3
            }
        }
    }
}

#Preview {
    VStack {
        MessageBubble(message: ChatMessage(role: .user, content: "What's my SOL balance?", timestamp: Date()))
        MessageBubble(message: ChatMessage(role: .assistant, content: "Your balance is 2.5 SOL on devnet.", timestamp: Date()))
        MessageBubble(message: ChatMessage(role: .error, content: "Network error", timestamp: Date()))
        MessageBubble(message: ChatMessage(role: .assistant, content: "", timestamp: Date(), isStreaming: true))
    }
    .padding()
}
