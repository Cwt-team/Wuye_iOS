import Combine
import Foundation

class LoginViewModel: ObservableObject {
    // 用户输入字段
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false

    // 执行本地账号密码登录
    func login(completion: ((Bool) -> Void)? = nil) {
        isLoading = true
        errorMessage = ""
        AuthManager.shared.loginWithPassword(
            phone_number: username,
            password: password,
            completion: { [weak self] success in
                DispatchQueue.main.async {
                    self?.isLoading = true
                    if !success {
                        self?.errorMessage = "用户名或密码错误"
                    }
                    completion?(success)
                }
            }
        )
    }
}
