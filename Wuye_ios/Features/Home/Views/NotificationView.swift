import SwiftUI

extension Home {
    struct NotificationView: View {
        // 示例通知数据
        private let notifications = [
            NotificationItem(id: 1, title: "物业费缴纳通知", content: "尊敬的业主，您的物业费将于本月15日到期，请及时缴纳。", date: "05-20", isRead: false),
            NotificationItem(id: 2, title: "停水通知", content: "因管道维修，小区将于本周六上午9点至下午2点停水，请提前做好准备。", date: "05-18", isRead: true)
        ]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // 标题栏
                HStack {
                    Text("通知公告")
                        .font(.headline)
                    
                    Spacer()
                    
                    NavigationLink(destination: Text("全部通知")) {
                        Text("查看全部")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                
                // 通知列表
                VStack(spacing: 0) {
                    ForEach(notifications) { item in
                        NotificationRow(item: item)
                        
                        if item.id != notifications.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // 通知数据模型
    struct NotificationItem: Identifiable {
        let id: Int
        let title: String
        let content: String
        let date: String
        let isRead: Bool
    }

    // 通知行视图
    struct NotificationRow: View {
        let item: NotificationItem
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                // 通知图标
                ZStack {
                    Circle()
                        .fill(item.isRead ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundColor(item.isRead ? .gray : .blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // 标题和日期
                    HStack {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(item.isRead ? .gray : .primary)
                        
                        Spacer()
                        
                        Text(item.date)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // 内容
                    Text(item.content)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle()) // 确保整行可点击
            .onTapGesture {
                // 处理点击通知
            }
        }
    }
}

struct NotificationView_Previews: PreviewProvider {
    static var previews: some View {
        Home.NotificationView()
            .previewLayout(.sizeThatFits)
            .padding(.vertical)
            .background(Color.gray.opacity(0.1))
    }
} 