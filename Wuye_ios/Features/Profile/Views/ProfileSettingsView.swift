import SwiftUI
import Combine

/// 个人资料设置视图
struct ProfileSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    // 用户信息
    @State private var name: String = ""
    @State private var mobile: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    
    // UI状态
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    @State private var showPhotoOptions = false
    
    // 取消订阅存储
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        Form {
            // 头像部分
            Section {
                HStack {
                    Spacer()
                    
                    Button(action: { showPhotoOptions = true }) {
                        VStack {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            Text("更换头像")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 5)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            
            // 基本信息
            Section(header: Text("基本信息")) {
                TextField("姓名", text: $name)
                TextField("手机号码", text: $mobile)
                    .disabled(true) // 通常手机号不可修改
                TextField("邮箱", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // 地址信息
            Section(header: Text("地址信息")) {
                TextField("居住地址", text: $address)
                    .frame(height: 60)
            }
            
            // 保存按钮
            Section {
                Button(action: saveProfile) {
                    HStack {
                        Spacer()
                        
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("保存")
                                .bold()
                        }
                        
                        Spacer()
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("个人资料")
        .navigationBarItems(
            trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            }
        )
        .onAppear(perform: loadUserData)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("提示"),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定")) {
                    if alertMessage.contains("成功") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
        .actionSheet(isPresented: $showPhotoOptions) {
            ActionSheet(
                title: Text("更换头像"),
                buttons: [
                    .default(Text("拍照")) {
                        // 实现拍照功能
                    },
                    .default(Text("从相册选择")) {
                        // 实现相册选择功能
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
    }
    
    // 加载用户数据
    private func loadUserData() {
        if let user = authManager.currentUser {
            self.name = user.username
            self.mobile = user.phone
            self.email = user.email
            self.address = user.address
        }
    }
    
    // 保存个人资料
    private func saveProfile() {
        // 表单验证
        if name.isEmpty {
            alertMessage = "姓名不能为空"
            showingAlert = true
            return
        }
        
        if !email.isEmpty && !isValidEmail(email) {
            alertMessage = "请输入有效的邮箱地址"
            showingAlert = true
            return
        }
        
        // 开始保存
        isSaving = true
        
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 更新用户信息
            if var user = authManager.currentUser {
                user.username = self.name
                user.email = self.email
                user.address = self.address
                
                // 保存用户信息到本地数据库
                let userRepository = RepositoryFactory.shared.getUserRepository()
                userRepository.saveUser(user: user)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                self.alertMessage = "保存失败: \(error.localizedDescription)"
                                self.showingAlert = true
                                self.isSaving = false
                            }
                        },
                        receiveValue: { savedUser in
                            // 更新AuthManager中的当前用户
                            self.authManager.currentUser = savedUser
                            
                            // 显示成功消息
                            self.alertMessage = "个人资料更新成功"
                            self.showingAlert = true
                            self.isSaving = false
                        }
                    )
                    .store(in: &cancellables) // 使用视图的 cancellables 集合
            } else {
                // 显示错误消息
                self.alertMessage = "更新失败，请稍后重试"
                self.showingAlert = true
                self.isSaving = false
            }
        }
    }
    
    // 验证邮箱格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// 预览
struct ProfileSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileSettingsView()
                .environmentObject(AuthManager.shared)
        }
    }
} 