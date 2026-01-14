import SwiftUI

struct PermissionBadge: View {
    var body: some View {
        Text("Permission")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.2))
            .foregroundStyle(Color.red)
            .clipShape(Capsule())
    }
}

struct CountBadge: View {
    let count: Int
    var highlighted: Bool = false

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((highlighted ? Color.red : Color.gray).opacity(0.2))
            .foregroundStyle(highlighted ? Color.red : Color.secondary)
            .clipShape(Capsule())
    }
}

struct ActivityIndicator: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(0.7)
    }
}

struct SessionSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
    }
}
