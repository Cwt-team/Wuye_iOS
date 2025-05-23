import SwiftUI

struct RegisterView: View {
    @State private var phone = ""
    @State private var code = ""
    @State private var password = ""
    @State private var isSendingCode = false
    // 如果你有 RegisterViewModel，可使用 @StateObject 替代上述 State

    var body: some View {
        VStack(spacing: 20) {
            TextField("手机号", text: $phone)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(.secondarySystemFill))
                .cornerRadius(8)

            HStack {
                TextField("验证码", text: $code)
                    .keyboardType(.numberPad)
                Button(isSendingCode ? "发送中…" : "获取验证码") {
                    sendCode()
                }
                .disabled(isSendingCode)
            }
            .padding()
            .background(Color(.secondarySystemFill))
            .cornerRadius(8)

            SecureField("密码（至少6位）", text: $password)
                .padding()
                .background(Color(.secondarySystemFill))
                .cornerRadius(8)

            Button("注册") {
                register()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)

            Spacer()
        }
        .padding()
        .navigationTitle("用户注册")
    }

    private func sendCode() {
        guard !phone.isEmpty else { return }
        isSendingCode = true
        // TODO: 调用你的验证码接口
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSendingCode = false
        }
    }

    private func register() {
        guard !phone.isEmpty, !code.isEmpty, password.count >= 6 else { return }
        // TODO: 调用你的注册接口，比如 AuthManager.shared.register(phone: phone, code: code, password: password)
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RegisterView()
        }
    }
}
