import SwiftUI

// 登录界面视图
struct LoginView: View {
    // 使用环境对象获取AuthManager
    @EnvironmentObject var authManager: AuthManager
    
    // 用户输入
    @State private var username = ""
    @State private var password = ""
    
    // 错误处理和状态
    @State private var errorMessage: String = ""
    @State private var usernameError: String?
    @State private var passwordError: String?
    @State private var isLoading = false
    
    // 主题
    @Environment(\.colorScheme) var colorScheme
    
    // 验证用户名
    private func validateUsername() -> Bool {
        if username.isEmpty {
            usernameError = "请输入手机号"
            return false
        }
        
        // 验证手机号格式
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        
        if !phonePredicate.evaluate(with: username) {
            usernameError = "请输入有效的手机号"
            return false
        }
        
        usernameError = nil
        return true
    }
    
    // 验证密码
    private func validatePassword() -> Bool {
        if password.isEmpty {
            passwordError = "请输入密码"
            return false
        }
        
        if password.count < 6 {
            passwordError = "密码不能少于6位"
            return false
        }
        
        passwordError = nil
        return true
    }
    
    // 执行登录
    private func login() {
        // 清除之前的错误
        errorMessage = ""
        
        // 验证表单
        let isUsernameValid = validateUsername()
        let isPasswordValid = validatePassword()
        
        if !isUsernameValid || !isPasswordValid {
            return
        }
        
        // 显示加载状态
        isLoading = true
        
        // 调用后端登录API
        authManager.loginWithPassword(
            phone_number: username,
            password: password,
            completion: { success in
                DispatchQueue.main.async { // 保证UI状态在主线程更新
                    isLoading = false
                    if success {
                        errorMessage = ""
                        authManager.isLoggedIn = true // 再次确保状态同步
                    } else {
                        errorMessage = "用户名或密码错误"
                    }
                }
            }
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 标题
                Text("物业管理系统")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                // 登录表单
                VStack(spacing: 15) {
                    // 测试账号提示
                    VStack(alignment: .leading, spacing: 5) {
                        Text("测试账号：")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("手机号: 13800001001")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("密码: pwd123")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 10)
                    .padding(.horizontal, 5)
                    
                    // 用户名输入框
                    VStack(alignment: .leading, spacing: 5) {
                        TextField("请输入手机号", text: $username)
                            .padding()
                            .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .onChange(of: username) { _ in
                                usernameError = nil
                            }
                            .keyboardType(.phonePad)  // 使用数字键盘
                        
                        if let error = usernameError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 4)
                        }
                    }
                    
                    // 密码输入框
                    VStack(alignment: .leading, spacing: 5) {
                        SecureField("密码", text: $password)
                            .padding()
                            .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .onChange(of: password) { _ in
                                passwordError = nil
                            }
                        
                        if let error = passwordError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 4)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 错误信息显示
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.top, 5)
                        .multilineTextAlignment(.center)
                }
                
                // 登录按钮
                Button(action: login) {
                    if isLoading {
                        HStack {
                            Text("登录中...")
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    } else {
                        Text("登录")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(isLoading)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 注册链接
                HStack {
                    Spacer()
                    Button("还没有账号？点击注册") {
                        // 跳转到注册页面的逻辑
                        print("跳转到注册页面")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 10)
                    Spacer()
                }
                
        
            }
            .padding(.bottom)
            .navigationBarHidden(true)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthManager.shared)
    }
}
