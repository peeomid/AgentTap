import SwiftUI

struct AgentIcon: View {
    let agentType: AgentType
    var size: CGFloat = 16
    var showBackground: Bool = true

    var body: some View {
        ZStack {
            if showBackground {
                Circle()
                    .fill(SessionHighlightStyle.agentBrand(for: agentType).opacity(0.2))
            }
            Image(systemName: agentType.iconName)
                .font(.system(size: size * 0.6, weight: .semibold))
                .foregroundStyle(SessionHighlightStyle.agentBrand(for: agentType))
        }
        .frame(width: size, height: size)
    }
}
