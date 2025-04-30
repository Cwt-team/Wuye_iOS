import Combine
import Foundation
import SwiftUI

// MARK: - 登录方式
enum LoginMethod {
    case password
    case verificationCode
}

// MARK: - 登录状态
enum LoginStatus: Equatable {
    case idle
    case sendingCode
    case codeSent
    case loggingIn
    case success
    case failure(String)
    
    static func == (lhs: LoginStatus, rhs: LoginStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.sendingCode, .sendingCode), (.codeSent, .codeSent), 
             (.loggingIn, .loggingIn), (.success, .success):
            return true
        case (.failure(let lhsMsg), .failure(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - 登录视图模型
class LoginViewModel: ObservableObject {
    // 用户输入字段
    @Published var phone: String = ""
    @Published var password: String = ""
    @Published var verificationCode: String = ""
    @Published var username: String = "" // 注册时使用
    
    // 状态
    @Published var loginMethod: LoginMethod = .password
    @Published var loginStatus: LoginStatus = .idle
    @Published var isRegisterMode: Bool = false
    @Published var isShowingTerms: Bool = false
    @Published var isTermsAccepted: Bool = false
    @Published var countdown: Int = 0 // 验证码倒计时
    
    // 验证结果
    @Published var phoneError: String?
    @Published var passwordError: String?
    @Published var codeError: String?
    @Published var usernameError: String?
    @Published var generalError: String?
    
    // 私有属性
    private let authManager = AuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?
    
    // MARK: - 公共方法
    
    /// 切换登录方式
    func toggleLoginMethod() {
        switch loginMethod {
        case .password:
            loginMethod = .verificationCode
        case .verificationCode:
            loginMethod = .password
        }
        clearErrors()
    }
    
    /// 切换注册模式
    func toggleRegisterMode() {
        isRegisterMode.toggle()
        if !isRegisterMode {
            username = ""
        }
        clearErrors()
    }
    
    /// 发送验证码
    func sendVerificationCode() {
        // 验证手机号
        if !validatePhone() {
            return
        }
        
        loginStatus = .sendingCode
        
        authManager.requestLoginCode(phone: phone) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.loginStatus = .codeSent
                    self.startCountdown()
                case .failure(let error):
                    self.loginStatus = .failure(error.localizedDescription)
                    self.generalError = error.localizedDescription
                }
            }
        }
    }
    
    /// 执行登录
    func login() {
        clearErrors()
        
        // 验证输入
        var isValidInput = true
        
        if !validatePhone() {
            isValidInput = false
        }
        
        if loginMethod == .password {
            if !validatePassword() {
                isValidInput = false
            }
        } else { // 验证码登录
            if !validateVerificationCode() {
                isValidInput = false
            }
        }
        
        if isRegisterMode && !validateUsername() {
            isValidInput = false
        }
        
        if isRegisterMode && !isTermsAccepted {
            generalError = "请阅读并同意用户协议和隐私政策"
            isValidInput = false
        }
        
        if !isValidInput {
            return
        }
        
        // 执行登录/注册逻辑
        loginStatus = .loggingIn
        
        if isRegisterMode {
            performRegister()
        } else {
            performLogin()
        }
    }
    
    /// 清除错误消息
    func clearErrors() {
        phoneError = nil
        passwordError = nil
        codeError = nil
        usernameError = nil
        generalError = nil
    }
    
    // MARK: - 私有方法
    
    /// 验证手机号
    private func validatePhone() -> Bool {
        if phone.isEmpty {
            phoneError = "请输入手机号"
            return false
        }
        
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        
        if !phonePredicate.evaluate(with: phone) {
            phoneError = "请输入有效的手机号"
            return false
        }
        
        return true
    }
    
    /// 验证密码
    private func validatePassword() -> Bool {
        if password.isEmpty {
            passwordError = "请输入密码"
            return false
        }
        
        if password.count < 6 {
            passwordError = "密码不能少于6位"
            return false
        }
        
        return true
    }
    
    /// 验证验证码
    private func validateVerificationCode() -> Bool {
        if verificationCode.isEmpty {
            codeError = "请输入验证码"
            return false
        }
        
        if verificationCode.count != 6 || !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: verificationCode)) {
            codeError = "请输入6位数字验证码"
            return false
        }
        
        return true
    }
    
    /// 验证用户名
    private func validateUsername() -> Bool {
        if username.isEmpty {
            usernameError = "请输入用户名"
            return false
        }
        
        if username.count < 2 || username.count > 20 {
            usernameError = "用户名长度应在2-20位之间"
            return false
        }
        
        return true
    }
    
    /// 执行登录操作
    private func performLogin() {
        if loginMethod == .password {
            // 密码登录 (旧版API可能不支持，这里为了兼容，实际应调整为服务端支持的方式)
            authManager.loginWithPassword(phone: phone, password: password) { [weak self] result in
                self?.handleAuthResult(result)
            }
        } else {
            // 验证码登录
            authManager.login(phone: phone, code: verificationCode) { [weak self] result in
                self?.handleAuthResult(result)
            }
        }
    }
    
    /// 执行注册操作
    private func performRegister() {
        if loginMethod == .verificationCode {
            // 使用验证码注册
            authManager.register(phone: phone, password: password, username: username) { [weak self] result in
                self?.handleAuthResult(result)
            }
        } else {
            // 暂不支持直接密码注册，需先获取验证码
            generalError = "注册需要验证码，请切换到验证码登录"
            loginStatus = .failure("注册需要验证码验证")
        }
    }
    
    /// 处理认证结果
    private func handleAuthResult(_ result: Result<Void, Error>) {
        DispatchQueue.main.async {
            switch result {
            case .success:
                self.loginStatus = .success
            case .failure(let error):
                self.loginStatus = .failure(error.localizedDescription)
                self.generalError = error.localizedDescription
            }
        }
    }
    
    /// 启动倒计时
    private func startCountdown() {
        countdown = 60
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                if self.countdown > 0 {
                    self.countdown -= 1
                } else {
                    timer.invalidate()
                    self.countdownTimer = nil
                }
            }
        }
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
}
