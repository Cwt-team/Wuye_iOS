import SwiftUI

struct NewLoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var isButtonPressed = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // 标题区域
                    VStack(spacing: 8) {
                        Text("欢迎使用物业助手")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        
                        Text(viewModel.isRegisterMode ? "注册新账号" : "登录您的账户")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    // 登录表单
                    VStack(spacing: 25) {
                        // 手机号输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("手机号")
                                .font(.callout)
                                .foregroundColor(.gray)
                            
                            TextField("请输入手机号", text: $viewModel.phone)
                                .keyboardType(.phonePad)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            if let error = viewModel.phoneError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // 登录方式切换
                        HStack {
                            Text("登录方式：")
                                .foregroundColor(.gray)
                            
                            Picker("登录方式", selection: Binding(
                                get: { viewModel.loginMethod },
                                set: { _ in viewModel.toggleLoginMethod() }
                            )) {
                                Text("密码登录").tag(LoginMethod.password)
                                Text("验证码登录").tag(LoginMethod.verificationCode)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        // 根据登录方式显示不同的输入区域
                        if viewModel.loginMethod == .password {
                            // 密码输入
                            VStack(alignment: .leading, spacing: 8) {
                                Text("密码")
                                    .font(.callout)
                                    .foregroundColor(.gray)
                                
                                SecureField("请输入密码", text: $viewModel.password)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                if let error = viewModel.passwordError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        } else {
                            // 验证码输入
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("验证码")
                                        .font(.callout)
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        viewModel.sendVerificationCode()
                                    }) {
                                        Text(viewModel.countdown > 0 ? "\(viewModel.countdown)秒后重试" : "获取验证码")
                                            .font(.caption)
                                            .foregroundColor(viewModel.countdown > 0 ? .gray : .purple)
                                    }
                                    .disabled(viewModel.countdown > 0 || viewModel.loginStatus == .sendingCode)
                                }
                                
                                // 使用我们自定义的验证码视图
                                VerificationCodeView(
                                    codeLength: 6,
                                    onCodeCompleted: { code in
                                        // 可以在这里添加验证码输入完成后的处理逻辑
                                    },
                                    code: $viewModel.verificationCode
                                )
                                
                                if let error = viewModel.codeError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        // 注册模式下显示用户名输入
                        if viewModel.isRegisterMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("用户名")
                                    .font(.callout)
                                    .foregroundColor(.gray)
                                
                                TextField("请输入用户名", text: $viewModel.username)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                if let error = viewModel.usernameError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // 用户协议
                            Toggle(isOn: $viewModel.isTermsAccepted) {
                                HStack {
                                    Text("我已阅读并同意")
                                        .font(.footnote)
                                    
                                    Button("《用户协议》和《隐私政策》") {
                                        viewModel.isShowingTerms = true
                                    }
                                    .font(.footnote)
                                    .foregroundColor(.purple)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .purple))
                        }
                        
                        // 通用错误提示
                        if let error = viewModel.generalError {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 登录按钮
                    Button(action: {
                        isButtonPressed = true
                        viewModel.login()
                        // 使用震动反馈
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isButtonPressed = false
                        }
                    }) {
                        HStack {
                            Text(viewModel.isRegisterMode ? "注册" : "登录")
                                .fontWeight(.semibold)
                            
                            if viewModel.loginStatus == .loggingIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.leading, 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isButtonPressed ? Color.purple.opacity(0.8) : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .scaleEffect(isButtonPressed ? 0.98 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isButtonPressed)
                    }
                    .disabled(viewModel.loginStatus == .loggingIn)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // 切换登录/注册模式
                    Button(action: {
                        viewModel.toggleRegisterMode()
                    }) {
                        Text(viewModel.isRegisterMode ? "已有账号？返回登录" : "没有账号？立即注册")
                            .foregroundColor(.purple)
                            .font(.callout)
                    }
                    .padding(.top, 15)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.isShowingTerms) {
                VStack {
                    Text("用户协议和隐私政策")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()
                    
                    ScrollView {
                        Text("这里是用户协议和隐私政策内容...")
                            .padding()
                    }
                    
                    Button("关闭") {
                        viewModel.isShowingTerms = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
                }
            }
        }
        .accentColor(.purple)
    }
}

#Preview {
    NewLoginView()
} 