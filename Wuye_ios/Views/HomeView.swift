import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. 用户信息区
                HeaderView()
                    .padding(.bottom, 8)
                
                // 2. 滚动内容区
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 2.1 轮播图
                        BannerView()
                        
                        // 2.2 功能九宫格
                        FeatureGridView()
                        
                        // 2.3 通知预览
                        NotificationView()
                        
                        // 2.4 生活服务横向滚动
                        LifeServiceView()
                    }
                    .padding(.top, 8)
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
            .accentColor(.purple)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

