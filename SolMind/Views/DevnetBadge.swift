import SwiftUI

// MARK: - Devnet Warning Badge

struct DevnetBadge: View {
    var body: some View {
        Label("DEVNET", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange, in: Capsule())
    }
}

#Preview {
    DevnetBadge()
        .padding()
}
