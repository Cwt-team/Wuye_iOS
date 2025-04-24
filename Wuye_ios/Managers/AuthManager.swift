import Combine
import Foundation
import SwiftUI

// ===== 1. 虚拟账户常量 =====
struct DemoUserInfo {
    static let phone       = "13800000000"   // 虚拟手机号
    static let defaultCode = "0000"           // 虚拟验证码
    static let password    = "123456"         // 虚拟密码
    static let name        = "测试用户"        // 虚拟昵称
    static let community   = "汤臣一品小区"       // 虚拟小区
}

// ===== 添加空响应类型 =====
struct EmptyResponse: Codable {}

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    // 原来使用 @AppStorage，这里改为手动 UserDefaults 存取
    @Published var token: String = UserDefaults.standard.string(forKey: "token") ?? "" {
        didSet {
            UserDefaults.standard.set(token, forKey: "token")
        }
    }
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?   // 记录登录用户信息

    private var cancellables = Set<AnyCancellable>()

    // 获取验证码
    func sendCode(to phone: String) -> AnyPublisher<Void, APIError> {
        if phone == DemoUserInfo.phone {
            // 虚拟账户直接返回成功
            return Just(())
                .setFailureType(to: APIError.self)
                .delay(for: .milliseconds(200), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        struct Req: Codable { let phone: String }
        let url = URL(string: "https://api.xxx.com/sendCode")!
        return APIService.shared.post(url: url, body: Req(phone: phone))
            .map { (_: EmptyResponse) in () }   // EmptyResponse 已定义
            .eraseToAnyPublisher()
    }

    // 登录
    func login(phone: String, password: String) {
        if phone == DemoUserInfo.phone && password == DemoUserInfo.password {
            // 虚拟登录分支
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.token = "demo_token"
                self.currentUser = User(id: 0,
                                        name: DemoUserInfo.name,
                                        avatarURL: nil,
                                        community: DemoUserInfo.community)
                self.isLoggedIn = true
            }
            return
        }
        struct Req: Codable { let phone: String; let password: String }
        let url = URL(string: "https://api.xxx.com/login")!
        APIService.shared.post(url: url, body: Req(phone: phone, password: password))
            .sink(receiveCompletion: { _ in }, receiveValue: { (resp: AuthResponse) in
                self.token = resp.token   // token 会写入 UserDefaults
                self.isLoggedIn = true
            })
            .store(in: &cancellables)
    }

    // 注册
    func register(phone: String, code: String, password: String) {
        if phone == DemoUserInfo.phone {
            // 虚拟注册与登录一致
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.token = "demo_token"
                self.currentUser = User(id: 0,
                                        name: DemoUserInfo.name,
                                        avatarURL: nil,
                                        community: DemoUserInfo.community)
                self.isLoggedIn = true
            }
            return
        }
        struct Req: Codable { let phone: String; let code: String; let password: String }
        let url = URL(string: "https://api.xxx.com/register")!
        APIService.shared.post(url: url, body: Req(phone: phone, code: code, password: password))
            .sink(receiveCompletion: { _ in }, receiveValue: { (resp: AuthResponse) in
                self.token = resp.token
                self.isLoggedIn = true
            })
            .store(in: &cancellables)
    }
}
