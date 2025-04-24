import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @ObservedObject private var auth = AuthManager.shared

    var body: some View {
        ZStack {
            // 背景白
            Color.white.ignoresSafeArea()
            VStack(spacing: 20) {
                // 手机号
                TextField("手机号", text: $vm.phone)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.secondarySystemFill))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 1))

                // 验证码 + 按钮
                HStack {
                    TextField("验证码", text: $vm.code)
                        .keyboardType(.numberPad)
                    Button(vm.isSendingCode ? "发送中…" : "获取验证码") {
                        vm.sendCode()
                    }
                    .disabled(vm.isSendingCode)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(vm.isSendingCode ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.secondarySystemFill))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 1))

                // 密码
                SecureField("密码", text: $vm.password)
                    .padding()
                    .background(Color(.secondarySystemFill))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 1))

                // 登录按钮
                Button("登录") {
                    vm.login()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(8)

                // 注册跳转
                NavigationLink("注册新用户", destination: RegisterView())
                    .padding(.top, 10)
                    .foregroundColor(.purple)

                Spacer()
            }
            .padding()
            .accentColor(.purple)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
