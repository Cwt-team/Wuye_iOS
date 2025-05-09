import SwiftUI

/// 关于我们视图
struct AboutView: View {
    @State private var showingLicense = false
    @State private var showingPrivacyPolicy = false
    @State private var showingUserAgreement = false
    
    // App信息
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        List {
            // App Logo和版本信息
            Section {
                VStack {
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                        .padding(.bottom, 10)
                    
                    Text("物业管理")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("版本 \(appVersion) (\(buildVersion))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                    
                    Text("© 2023 物业管理公司 版权所有")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            
            // 法律信息
            Section(header: Text("法律信息")) {
                Button(action: {
                    showingPrivacyPolicy = true
                }) {
                    AboutSettingRow(title: "隐私政策", icon: "hand.raised.fill", color: .blue)
                }
                
                Button(action: {
                    showingUserAgreement = true
                }) {
                    AboutSettingRow(title: "用户协议", icon: "doc.text.fill", color: .purple)
                }
                
                Button(action: {
                    showingLicense = true
                }) {
                    AboutSettingRow(title: "开源许可", icon: "doc.on.doc.fill", color: .orange)
                }
            }
            
            // 联系信息
            Section(header: Text("联系我们")) {
                Link(destination: URL(string: "https://www.wuyeapp.com")!) {
                    AboutSettingRow(title: "官方网站", icon: "globe", color: .green)
                }
                
                Link(destination: URL(string: "mailto:support@wuyeapp.com")!) {
                    AboutSettingRow(title: "电子邮件", icon: "envelope.fill", color: .blue)
                }
                
                Link(destination: URL(string: "tel:4001234567")!) {
                    AboutSettingRow(title: "客服热线", icon: "phone.fill", color: .green)
                }
            }
            
            // 社交媒体
            Section(header: Text("关注我们")) {
                Link(destination: URL(string: "https://weibo.com/wuyeapp")!) {
                    AboutSettingRow(title: "官方微博", icon: "w.circle.fill", color: .red)
                }
                
                Button(action: {
                    // 打开微信小程序或公众号
                    UIPasteboard.general.string = "wuyeapp"
                }) {
                    HStack {
                        Image(systemName: "applescript.fill")
                            .foregroundColor(.green)
                            .frame(width: 30, height: 30)
                        
                        Text("微信公众号")
                        
                        Spacer()
                        
                        Text("wuyeapp")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // 评分
            Section {
                Link(destination: URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review")!) {
                    HStack {
                        Spacer()
                        
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        
                        Text("给我们评分")
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("关于我们")
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingUserAgreement) {
            UserAgreementView()
        }
        .sheet(isPresented: $showingLicense) {
            OpenSourceLicenseView()
        }
    }
}

// 设置行组件 - 用于AboutView
struct AboutSettingRow: View {
    var title: String
    var icon: String
    var color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30, height: 30)
            
            Text(title)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// 隐私政策视图
struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("隐私政策")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 20)
                    
                    Text("最后更新: 2023年9月1日")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                    
                    Text("我们非常重视您的隐私，本隐私政策旨在告知您我们如何收集、使用、共享和保护您的个人信息。")
                    
                    Text("信息收集和使用")
                        .font(.headline)
                    
                    Text("为了提供更好的服务，我们可能会收集您的个人信息，包括但不限于姓名、电话号码、电子邮件地址和位置信息。")
                    
                    Text("我们使用这些信息用于以下目的：")
                    
                    BulletList(items: [
                        "提供和改进我们的服务",
                        "处理您的请求和交易",
                        "发送通知和更新",
                        "提供客户支持",
                        "分析和优化用户体验"
                    ])
                    
                    // 添加更多隐私政策内容...
                }
                .padding()
            }
            .navigationBarItems(
                trailing: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// 用户协议视图
struct UserAgreementView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("用户协议")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 20)
                    
                    Text("最后更新: 2023年9月1日")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                    
                    Text("欢迎使用物业管理APP。请仔细阅读以下条款，使用我们的服务即表示您同意这些条款。")
                    
                    Text("账户注册")
                        .font(.headline)
                    
                    Text("您需要注册账户才能使用我们的某些服务。您需要提供准确、完整的信息，并保护您的账户安全。")
                    
                    Text("服务规则")
                        .font(.headline)
                    
                    Text("您在使用我们的服务时，必须遵守所有适用的法律和法规，不得从事任何违法或侵害他人权益的活动。")
                    
                    // 添加更多用户协议内容...
                }
                .padding()
            }
            .navigationBarItems(
                trailing: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// 开源许可视图
struct OpenSourceLicenseView: View {
    @Environment(\.presentationMode) var presentationMode
    
    private let licenses = [
        License(name: "Alamofire", url: "https://github.com/Alamofire/Alamofire", license: "MIT"),
        License(name: "SwiftyJSON", url: "https://github.com/SwiftyJSON/SwiftyJSON", license: "MIT"),
        License(name: "Kingfisher", url: "https://github.com/onevcat/Kingfisher", license: "MIT"),
        License(name: "Linphone", url: "https://github.com/BelledonneCommunications/linphone-iphone", license: "GPL")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(licenses) { license in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(license.name)
                            .font(.headline)
                        
                        Text("许可证: \(license.license)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Link(license.url, destination: URL(string: license.url)!)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("开源许可")
            .navigationBarItems(
                trailing: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// 开源许可模型
struct License: Identifiable {
    var id = UUID()
    var name: String
    var url: String
    var license: String
}

// 项目符号列表组件
struct BulletList: View {
    var items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                    Text("•")
                        .font(.headline)
                        .padding(.trailing, 5)
                    
                    Text(item)
                }
            }
        }
    }
}

// 预览
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AboutView()
        }
    }
} 