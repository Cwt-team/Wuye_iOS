import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea() // 彻底全屏白底
            VStack(spacing: 0) {
                // 1. 用户信息区
                Home.HeaderView()
                    .padding(.bottom, 8)
                
                // 2. 滚动内容区
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 2.1 轮播图
                        Home.BannerView()
                        
                        // 2.2 功能九宫格
                        Home.FeatureGridView()
                        
                        // 2.3 通知预览
                        Home.NotificationView()
                        
                        // 2.4 生活服务横向滚动
                        Home.LifeServiceView()
                    }
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            print("HomeView appeared - User: \(authManager.currentUser?.username ?? "Unknown")")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthManager.shared)
    }
}

