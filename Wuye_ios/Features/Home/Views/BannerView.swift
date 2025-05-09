import SwiftUI

enum Home {}

extension Home {
    struct BannerView: View {
        @State private var currentIndex = 0
        private let banners = [
            Banner(id: 1, title: "小区活动", imageSystemName: "figure.wave", color: .blue),
            Banner(id: 2, title: "物业公告", imageSystemName: "megaphone", color: .orange),
            Banner(id: 3, title: "业主福利", imageSystemName: "gift", color: .red)
        ]
        
        // 自动滚动计时器
        @State private var timer: Timer?
        
        var body: some View {
            VStack(spacing: 8) {
                TabView(selection: $currentIndex) {
                    ForEach(0..<banners.count, id: \.self) { index in
                        BannerCard(banner: banners[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 160)
                .onAppear {
                    // 启动自动滚动计时器
                    startTimer()
                }
                .onDisappear {
                    // 停止计时器
                    stopTimer()
                }
                
                // 页面指示器
                HStack(spacing: 6) {
                    ForEach(0..<banners.count, id: \.self) { index in
                        Circle()
                            .fill(currentIndex == index ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
        }
        
        // 启动定时器
        private func startTimer() {
            timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation {
                    currentIndex = (currentIndex + 1) % banners.count
                }
            }
        }
        
        // 停止定时器
        private func stopTimer() {
            timer?.invalidate()
            timer = nil
        }
    }

    // 轮播图数据模型
    struct Banner: Identifiable {
        let id: Int
        let title: String
        let imageSystemName: String
        let color: Color
    }

    // 轮播图卡片视图
    struct BannerCard: View {
        let banner: Banner
        
        var body: some View {
            ZStack(alignment: .bottomLeading) {
                // 背景色块
                RoundedRectangle(cornerRadius: 12)
                    .fill(banner.color.opacity(0.15))
                
                // 图片
                Image(systemName: banner.imageSystemName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(banner.color)
                    .offset(x: 200, y: -20)
                    .opacity(0.5)
                
                // 标题
                Text(banner.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(banner.color)
                    .padding(20)
            }
            .frame(height: 160)
            .cornerRadius(12)
        }
    }
}

struct BannerView_Previews: PreviewProvider {
    static var previews: some View {
        Home.BannerView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 