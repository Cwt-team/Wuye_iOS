import SwiftUI

extension Home {
    struct FeatureGridView: View {
        // 功能项数据（已删减）
        private let features = [
            FeatureItem(id: 1, title: "门禁开锁", icon: "lock.open.fill", color: .purple, destination: .unlock),
            FeatureItem(id: 2, title: "访客邀请", icon: "person.badge.plus", color: .green, destination: .visitor),
            FeatureItem(id: 4, title: "小区公告", icon: "megaphone.fill", color: .pink, destination: .notice),
            FeatureItem(id: 5, title: "周边商家", icon: "bag.fill", color: .yellow, destination: .merchant)
        ]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // 标题
                Text("服务中心")
                    .font(.headline)
                    .padding(.leading, 16)
                    .foregroundColor(.primary)
                
                // 功能网格
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(features) { feature in
                        FeatureButton(feature: feature)
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemBackground))
        }
    }
    
    // 功能项
    struct FeatureItem: Identifiable {
        let id: Int
        let title: String
        let icon: String
        let color: Color
        let destination: FeatureDestination
        
        enum FeatureDestination {
            case unlock, visitor, notice, merchant
        }
    }
    
    // 功能按钮
    struct FeatureButton: View {
        let feature: FeatureItem
        @State private var isActive = false
        
        var body: some View {
            VStack(spacing: 8) {
                // 图标
                ZStack {
                    Circle()
                        .fill(feature.color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: feature.icon)
                        .font(.system(size: 20))
                        .foregroundColor(feature.color)
                }
                
                // 标题
                Text(feature.title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            .frame(height: 80)
            .onTapGesture {
                isActive = true
                handleNavigation()
            }
            .background(
                NavigationLink(destination: destinationView(), isActive: $isActive) {
                    EmptyView()
                }
                .opacity(0)
            )
        }
        
        private func handleNavigation() {
            // 可扩展
        }
        
        @ViewBuilder
        private func destinationView() -> some View {
            switch feature.destination {
            case .unlock:
                UnlockView()
            case .visitor:
                Text("访客邀请功能")
            case .notice:
                Text("小区公告功能")
            case .merchant:
                Text("周边商家功能")
            }
        }
    }
}

struct FeatureGridView_Previews: PreviewProvider {
    static var previews: some View {
        Home.FeatureGridView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
