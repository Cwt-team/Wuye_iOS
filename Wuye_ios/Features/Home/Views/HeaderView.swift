import SwiftUI

extension Home {
    struct HeaderView: View {
        @EnvironmentObject var authManager: AuthManager
        
        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // 头像
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                    
                    // 用户信息
                    VStack(alignment: .leading, spacing: 2) {
                        Text("欢迎，\(authManager.currentUser?.username ?? "访客")")
                            .font(.headline)
                        
                        Text(authManager.currentUser?.community ?? "您的小区")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // 消息图标
                    Button(action: {
                        // 打开消息中心
                    }) {
                        Image(systemName: "bell")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    // 扫描图标
                    Button(action: {
                        // 打开扫描功能
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // 分隔线
                Divider()
            }
            .background(Color.white)
        }
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        Home.HeaderView()
            .environmentObject(AuthManager.shared)
            .previewLayout(.sizeThatFits)
    }
} 