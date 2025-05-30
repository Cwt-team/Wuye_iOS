import SwiftUI

struct MessagingView: View {
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("搜索联系人或消息", text: $searchText)
                        .font(.system(size: 16))
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                // 标签栏
                TabView(selection: $selectedTab) {
                    // 消息列表
                    MessageListView()
                        .tabItem {
                            Text("消息")
                        }
                        .tag(0)
                    
                    // 通话记录
                    CallHistoryView()
                        .tabItem {
                            Text("通话")
                        }
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 底部选项卡
                HStack(spacing: 0) {
                    TabButton(title: "消息", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    
                    TabButton(title: "通话", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    
                    TabButton(title: "联系人", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: -2)
            }
            .navigationTitle("消息中心")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// 消息列表视图
struct MessageListView: View {
    var body: some View {
        List {
            ForEach(MessageData.sampleMessages) { message in
                MessageRow(message: message)
            }
        }
        .listStyle(PlainListStyle())
    }
}

// 通话记录视图
struct CallHistoryView: View {
    var body: some View {
        List {
            ForEach(CallData.sampleCalls) { call in
                CallHistoryRow(call: call)
            }
        }
        .listStyle(PlainListStyle())
    }
}


// 底部选项卡按钮
struct TabButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .blue : .gray)
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// 消息行视图
struct MessageRow: View {
    var message: Message
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(message.isOfficial ? Color.blue : Color.gray)
                    .frame(width: 50, height: 50)
                
                if message.isOfficial {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                }
            }
            
            // 消息内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.sender)
                        .font(.headline)
                    
                    if message.isOfficial {
                        Text("官方")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(message.time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if message.unreadCount > 0 {
                    HStack {
                        Spacer()
                        
                        Text("\(message.unreadCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// 通话记录行视图
struct CallHistoryRow: View {
    var call: Call
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(call.isOfficial ? Color.blue : Color.gray)
                    .frame(width: 50, height: 50)
                
                if call.isOfficial {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                }
            }
            
            // 通话信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(call.name)
                        .font(.headline)
                    
                    if call.isOfficial {
                        Text("官方")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(call.time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    // 通话类型图标
                    Image(systemName: call.isIncoming ? "phone.arrow.down.left.fill" : "phone.arrow.up.right.fill")
                        .foregroundColor(call.isIncoming ? .green : .blue)
                    
                    // 通话状态
                    Text(call.status)
                        .font(.subheadline)
                        .foregroundColor(call.status == "未接听" ? .red : .secondary)
                    
                    if !call.duration.isEmpty {
                        Text("·")
                            .foregroundColor(.secondary)
                        
                        Text(call.duration)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 回拨按钮
            Button(action: {
                // 回拨操作
            }) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 8)
    }
}

// 联系人行视图
struct MessageContactRow: View {
    var name: String
    var number: String
    var isOfficial: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(isOfficial ? Color.blue : Color.gray)
                    .frame(width: 50, height: 50)
                
                if isOfficial {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                }
            }
            
            // 联系人信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.headline)
                    
                    if isOfficial {
                        Text("官方")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                
                Text(number)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 拨打按钮
            Button(action: {
                // 拨打操作
            }) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 8)
    }
}

// 数据模型
struct Message: Identifiable {
    var id = UUID()
    var sender: String
    var content: String
    var time: String
    var unreadCount: Int
    var isOfficial: Bool = false
}

struct Call: Identifiable {
    var id = UUID()
    var name: String
    var time: String
    var isIncoming: Bool
    var status: String
    var duration: String
    var isOfficial: Bool = false
}

// 示例数据
struct MessageData {
    static let sampleMessages = [
        Message(sender: "物业服务中心", content: "尊敬的业主，本周日将进行小区绿化维护，请配合工作人员。", time: "09:30", unreadCount: 2, isOfficial: true),
        Message(sender: "安保中心", content: "您有新的访客申请，请查看并确认。", time: "昨天", unreadCount: 0, isOfficial: true),
        Message(sender: "李四", content: "下午小区有活动吗？", time: "周一", unreadCount: 0),
        Message(sender: "维修中心", content: "您的维修申请已受理，维修人员将于明天上午10点到访。", time: "周日", unreadCount: 0, isOfficial: true),
        Message(sender: "张三", content: "明天有业主委员会吗？", time: "上周五", unreadCount: 0)
    ]
}

struct CallData {
    static let sampleCalls = [
        Call(name: "物业服务中心", time: "今天 14:23", isIncoming: true, status: "已接听", duration: "4:32", isOfficial: true),
        Call(name: "物业服务中心", time: "昨天 10:15", isIncoming: false, status: "已接听", duration: "1:05", isOfficial: true),
        Call(name: "安保中心", time: "前天 18:42", isIncoming: true, status: "未接听", duration: "", isOfficial: true),
        Call(name: "张三", time: "2023-09-01 11:30", isIncoming: false, status: "已接听", duration: "2:15"),
        Call(name: "维修中心", time: "2023-08-28 09:12", isIncoming: true, status: "已接听", duration: "5:48", isOfficial: true)
    ]
}

// 预览
struct MessagingView_Previews: PreviewProvider {
    static var previews: some View {
        MessagingView()
    }
} 
