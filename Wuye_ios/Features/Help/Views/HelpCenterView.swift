import SwiftUI

/// 帮助中心视图
struct HelpCenterView: View {
    // 常见问题列表
    private let faqItems = [
        FAQItem(
            id: UUID(),
            question: "如何修改个人信息？",
            answer: "您可以在\"我的\"页面中点击\"个人资料\"，然后修改您的个人信息，包括姓名、邮箱和地址等。"
        ),
        FAQItem(
            id: UUID(),
            question: "如何提交报修申请？",
            answer: "在首页或者\"报修\"页面，点击\"新建报修\"按钮，填写报修信息，上传照片，然后提交即可。"
        ),
        FAQItem(
            id: UUID(),
            question: "如何设置SIP来电？",
            answer: "进入\"我的\"页面，点击\"SIP通话设置\"，填写SIP服务器信息和账号信息，然后点击\"保存并注册\"按钮。"
        ),
        FAQItem(
            id: UUID(),
            question: "如何查看缴费记录？",
            answer: "在\"我的\"页面中，点击\"缴费记录\"选项，您可以查看所有的缴费历史和未缴费项目。"
        ),
        FAQItem(
            id: UUID(),
            question: "忘记密码如何找回？",
            answer: "在登录页面，点击\"忘记密码\"选项，然后按照指示通过手机验证码重置密码。"
        ),
        FAQItem(
            id: UUID(),
            question: "如何联系客服？",
            answer: "您可以在\"我的\"页面中找到\"联系客服\"选项，或者直接拨打页面底部的客服电话。"
        ),
        FAQItem(
            id: UUID(),
            question: "如何查看公告信息？",
            answer: "在首页顶部的公告栏或者\"消息\"页面中的\"公告\"选项卡中查看所有公告信息。"
        ),
        FAQItem(
            id: UUID(),
            question: "如何更改通知设置？",
            answer: "在\"我的\"页面中，点击\"通知设置\"，然后根据需要打开或关闭不同类型的通知。"
        )
    ]
    
    @State private var searchText = ""
    @State private var selectedFAQ: FAQItem? = nil
    @State private var showingContactSheet = false
    
    var filteredFAQs: [FAQItem] {
        if searchText.isEmpty {
            return faqItems
        } else {
            return faqItems.filter { item in
                item.question.localizedCaseInsensitiveContains(searchText) ||
                item.answer.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索帮助", text: $searchText)
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
            .padding()
            
            // 常见问题列表
            List {
                Section(header: Text("常见问题")) {
                    ForEach(filteredFAQs) { item in
                        FAQItemView(item: item)
                    }
                }
                
                Section(header: Text("联系客服")) {
                    Button(action: {
                        showingContactSheet = true
                    }) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                            
                            Text("联系客服")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("帮助中心")
        .sheet(isPresented: $showingContactSheet) {
            ContactSupportView()
        }
    }
}

// FAQ项目
struct FAQItem: Identifiable {
    var id: UUID
    var question: String
    var answer: String
}

// FAQ项目视图
struct FAQItemView: View {
    let item: FAQItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(item.question)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if isExpanded {
                Text(item.answer)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
                    .padding(.bottom, 5)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 5)
    }
}

// 联系客服视图
struct ContactSupportView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var message = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("联系方式")) {
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(.green)
                            .frame(width: 24, height: 24)
                        
                        Text("客服热线")
                        
                        Spacer()
                        
                        Button("400-123-4567") {
                            // 拨打电话
                            guard let url = URL(string: "tel:4001234567") else { return }
                            UIApplication.shared.open(url)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        
                        Text("电子邮箱")
                        
                        Spacer()
                        
                        Button("support@wuyeapp.com") {
                            // 发送邮件
                            guard let url = URL(string: "mailto:support@wuyeapp.com") else { return }
                            UIApplication.shared.open(url)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Image(systemName: "bubble.left")
                            .foregroundColor(.orange)
                            .frame(width: 24, height: 24)
                        
                        Text("在线客服")
                        
                        Spacer()
                        
                        Text("工作时间: 9:00-18:00")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("留言反馈")) {
                    TextEditor(text: $message)
                        .frame(height: 120)
                        .background(Color(.systemBackground))
                    
                    Button(action: {
                        // 提交留言
                        showingAlert = true
                        message = ""
                    }) {
                        HStack {
                            Spacer()
                            Text("提交留言")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(message.isEmpty)
                }
            }
            .navigationTitle("联系客服")
            .navigationBarItems(
                trailing: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("留言已提交"),
                    message: Text("我们将尽快回复您的留言，感谢您的反馈！"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
}

// 预览
struct HelpCenterView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HelpCenterView()
        }
    }
} 