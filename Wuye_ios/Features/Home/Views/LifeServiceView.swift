import SwiftUI

extension Home {
    struct LifeServiceView: View {
        // 生活服务数据
        private let services = [
            ServiceItem(id: 1, title: "快递代收", icon: "shippingbox.fill", color: .blue),
            ServiceItem(id: 2, title: "社区团购", icon: "cart.fill", color: .green),
            ServiceItem(id: 3, title: "家政服务", icon: "house.fill", color: .orange),
            ServiceItem(id: 4, title: "水电维修", icon: "wrench.fill", color: .red),
            ServiceItem(id: 5, title: "便民超市", icon: "bag.fill", color: .purple)
        ]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // 标题
                HStack {
                    Text("生活服务")
                        .font(.headline)
                    
                    Spacer()
                    
                    NavigationLink(destination: Text("全部服务")) {
                        Text("更多")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                
                // 横向滚动服务
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(services) { service in
                            ServiceCard(service: service)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // 服务项数据模型
    struct ServiceItem: Identifiable {
        let id: Int
        let title: String
        let icon: String
        let color: Color
    }

    // 服务卡片视图
    struct ServiceCard: View {
        let service: ServiceItem
        
        var body: some View {
            VStack(spacing: 12) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(service.color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: service.icon)
                        .font(.system(size: 24))
                        .foregroundColor(service.color)
                }
                
                // 标题
                Text(service.title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 80)
            .onTapGesture {
                // 处理点击服务
            }
        }
    }
}

struct LifeServiceView_Previews: PreviewProvider {
    static var previews: some View {
        Home.LifeServiceView()
            .previewLayout(.sizeThatFits)
            .padding(.vertical)
            .background(Color.gray.opacity(0.1))
    }
} 