import Foundation
import Combine
import Alamofire

// MARK: - 认证响应模型（AuthManager内部使用）
private struct AuthManagerLoginResponse: Codable {
    let token: String
    let user: User
    
    // 手动实现Decodable以确保User类型解码正确
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        user = try container.decode(User.self, forKey: .user)
    }
    
    // 定义CodingKeys以明确字段映射
    private enum CodingKeys: String, CodingKey {
        case token
        case user
    }
}

// MARK: - 认证状态
enum AuthStatus {
    case authenticated
    case unauthenticated
    case verifying
}

// MARK: - 认证管理器
class AuthManager: ObservableObject {
    // 单例实例
    static let shared = AuthManager()
    
    // 发布属性
    @Published var status: AuthStatus = .verifying
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    
    // 私有属性
    private let keychainHelper = KeychainHelper.shared
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private let userRepository: UserRepositoryProtocol
    
    // 计算属性
    var isAuthenticated: Bool {
        return status == .authenticated && currentUser != nil
    }
    
    // 私有初始化方法
    private init() {
        userRepository = RepositoryFactory.shared.getUserRepository()
    }
    
    // MARK: - 公共方法
    
    /// 检查当前认证状态
    func checkAuthStatus() {
        // 设置状态为正在验证
        status = .verifying
        
        // 检查是否存在有效的令牌
        if let token = keychainHelper.get(service: "auth", account: "token") {
            // 尝试获取当前用户
            userRepository.getCurrentUser()
                .receive(on: DispatchQueue.main) // 确保在主线程上接收结果
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure = completion {
                            self?.logout()
                        }
                    },
                    receiveValue: { [weak self] user in
                        if let user = user {
                            self?.currentUser = user
                            self?.status = .authenticated
                            self?.isLoggedIn = true
                        } else {
                            self?.validateToken(token)
                        }
                    }
                )
                .store(in: &cancellables)
        } else {
            // 无令牌，设置为未认证状态
            status = .unauthenticated
            isLoggedIn = false
        }
    }
    
    /// 使用密码登录 - 连接到后台管理系统API
    /// - Parameters:
    ///   - phone: 手机号/用户名
    ///   - password: 密码
    ///   - completion: 完成回调
    func loginWithPassword(phone: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        #if DEBUG
        print("🔑 尝试登录: \(phone)")
        print("🌐 请求URL: \(APIService.shared.currentBaseURL)/mobile/login")
        let startTime = Date()
        #endif
        
        // 注意：endpoint不要以/api开头，因为APIService的currentBaseURL已经包含了/api
        // 后端路由是/api/mobile/login，但在这里只需要写/mobile/login
        apiService.simpleRequest(
            endpoint: "/mobile/login",
            method: "POST",
            body: ["account": phone, "password": password],  // 使用account作为参数名
            useFormData: true,  // 使用表单数据格式
            requiresAuth: false
        ) { [weak self] (result: Result<Models.AdminLoginResponse, Error>) in
            #if DEBUG
            let requestDuration = Date().timeIntervalSince(startTime)
            print("⏱️ 登录请求耗时: \(String(format: "%.2f", requestDuration))秒")
            #endif
            
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    #if DEBUG
                    print("✅ 收到登录响应: success=\(response.success)")
                    if let message = response.message {
                        print("📝 响应消息: \(message)")
                    }
                    if let ownerInfo = response.ownerInfo {
                        print("👤 用户信息: id=\(ownerInfo.id), username=\(ownerInfo.username)")
                    } else {
                        print("⚠️ 响应中无用户信息")
                    }
                    #endif
                    
                    if response.success {
                        guard let ownerInfo = response.ownerInfo else {
                            completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "登录成功但未返回用户信息"])))
                            return
                        }
                        
                        #if DEBUG
                        print("🎉 登录成功: \(phone)")
                        #endif
                        
                        // 构建用户对象
                        let user = User(
                            id: ownerInfo.id,
                            username: ownerInfo.username,
                            password: "",  // 不存储密码
                            phone: ownerInfo.phone,
                            email: ownerInfo.email ?? "",
                            address: ownerInfo.address ?? "",
                            avatarURL: nil,
                            community: nil
                        )
                        
                        // 从响应获取token，如果响应没有提供token则生成一个临时token
                        // 在实际项目中，服务器应该返回一个真实的认证token
                        // 这里我们使用message字段作为token，如果没有则创建一个临时token
                        let token = response.message ?? UUID().uuidString
                        
                        #if DEBUG
                        print("🔑 保存令牌: \(String(token.prefix(5)))...")
                        #endif
                        
                        // 保存令牌
                        self?.keychainHelper.save(token, service: "auth", account: "token")
                        
                        // 保存用户信息
                        self?.userRepository.saveUser(user: user)
                            .receive(on: DispatchQueue.main)
                            .sink(
                                receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        #if DEBUG
                                        print("❌ 保存用户信息失败: \(error.localizedDescription)")
                                        #endif
                                    }
                                },
                                receiveValue: { [weak self] savedUser in
                                    #if DEBUG
                                    print("✅ 保存用户信息成功，ID: \(savedUser.id)")
                                    #endif
                                    
                                    self?.currentUser = savedUser
                                    self?.status = .authenticated
                                    self?.isLoggedIn = true
                                    completion(.success(()))
                                }
                            )
                            .store(in: &self!.cancellables)
                    } else {
                        let errorMessage = response.message ?? "登录失败"
                        #if DEBUG
                        print("❌ 登录失败: \(errorMessage)")
                        #endif
                        completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    }
                case .failure(let error):
                    self?.status = .unauthenticated
                    self?.isLoggedIn = false
                    #if DEBUG
                    print("❌ 登录请求失败: \(error.localizedDescription)")
                    
                    // 尝试提供更详细的错误信息
                    if let urlError = error as? URLError {
                        print("   🔍 URL错误码: \(urlError.code.rawValue)")
                        switch urlError.code {
                        case .timedOut:
                            print("   ⏰ 请求超时 - 检查服务器是否正在运行，或网络连接是否稳定")
                        case .cannotConnectToHost:
                            print("   🔌 无法连接到主机 - 检查服务器地址是否正确")
                        case .notConnectedToInternet:
                            print("   📡 设备未连接到互联网 - 检查网络连接")
                        default:
                            print("   🧩 其他URL错误: \(urlError.localizedDescription)")
                        }
                    } else if let afError = error as? AFError {
                        print("   🔍 Alamofire错误: \(afError)")
                        if let underlyingError = afError.underlyingError {
                            print("   🔍 底层错误: \(underlyingError)")
                        }
                    } else {
                        print("   🔍 一般错误: \(error)")
                    }
                    
                    print("   🔧 建议: 检查服务器是否运行在正确的地址和端口(192.168.1.21:5000)上")
                    #endif
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 使用手机号和验证码登录
    /// - Parameters:
    ///   - phone: 手机号
    ///   - code: 验证码
    ///   - completion: 完成回调
    func login(phone: String, code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        apiService.request(
            endpoint: "/auth/login",
            method: HTTPMethod.post,
            parameters: ["phone": phone, "code": code],
            requiresAuth: false
        ) { [weak self] (result: Result<Models.UserResponse, APIError>) in
            DispatchQueue.main.async { // 确保在主线程上处理结果
                switch result {
                case .success(let response):
                    if response.success, let token = response.message {
                        // 保存令牌
                        self?.keychainHelper.save(token, service: "auth", account: "token")
                        
                        // 保存用户信息
                        self?.userRepository.saveUser(user: response.user)
                            .receive(on: DispatchQueue.main) // 确保在主线程上接收结果
                            .sink(
                                receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        print("保存用户信息失败: \(error.localizedDescription)")
                                    }
                                },
                                receiveValue: { [weak self] user in
                                    self?.currentUser = user
                                    self?.status = .authenticated
                                    self?.isLoggedIn = true
                                    completion(.success(()))
                                }
                            )
                            .store(in: &self!.cancellables)
                    } else {
                        self?.status = .unauthenticated
                        self?.isLoggedIn = false
                        completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: response.message ?? "登录失败"])))
                    }
                    
                case .failure(let error):
                    self?.status = .unauthenticated
                    self?.isLoggedIn = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 使用手机号、密码和用户信息注册
    /// - Parameters:
    ///   - phone: 手机号
    ///   - password: 密码
    ///   - username: 用户名
    ///   - completion: 完成回调
    func register(phone: String, password: String, username: String, completion: @escaping (Result<Void, Error>) -> Void) {
        apiService.request(
            endpoint: "/auth/register",
            method: HTTPMethod.post,
            parameters: [
                "phone": phone,
                "password": password,
                "username": username
            ],
            requiresAuth: false
        ) { [weak self] (result: Result<Models.UserResponse, APIError>) in
            DispatchQueue.main.async { // 确保在主线程上处理结果
                switch result {
                case .success(let response):
                    if response.success, let token = response.message {
                        // 保存令牌
                        self?.keychainHelper.save(token, service: "auth", account: "token")
                        
                        // 保存用户信息
                        self?.userRepository.saveUser(user: response.user)
                            .receive(on: DispatchQueue.main) // 确保在主线程上接收结果
                            .sink(
                                receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        print("保存用户信息失败: \(error.localizedDescription)")
                                    }
                                },
                                receiveValue: { [weak self] user in
                                    self?.currentUser = user
                                    self?.status = .authenticated
                                    self?.isLoggedIn = true
                                    completion(.success(()))
                                }
                            )
                            .store(in: &self!.cancellables)
                    } else {
                        self?.status = .unauthenticated
                        self?.isLoggedIn = false
                        completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: response.message ?? "注册失败"])))
                    }
                case .failure(let error):
                    self?.status = .unauthenticated
                    self?.isLoggedIn = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 退出登录
    func logout() {
        // 清理当前用户和认证状态
        currentUser = nil
        status = .unauthenticated
        isLoggedIn = false
        
        // 移除令牌
        keychainHelper.delete(service: "auth", account: "token")
        
        // 重置本地数据
        userRepository.deleteCurrentUser()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    /// 请求验证码
    /// - Parameters:
    ///   - phone: 手机号
    ///   - completion: 完成回调
    func requestLoginCode(phone: String, completion: @escaping (Result<Void, Error>) -> Void) {
        apiService.request(
            endpoint: "/auth/request-code",
            method: HTTPMethod.post,
            parameters: ["phone": phone],
            requiresAuth: false
        ) { (result: Result<EmptyResponse, APIError>) in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 验证令牌
    /// - Parameter token: 令牌字符串
    private func validateToken(_ token: String) {
        apiService.request(
            endpoint: "/auth/validate-token",
            method: HTTPMethod.get,
            requiresAuth: true
        ) { [weak self] (result: Result<User, APIError>) in
            switch result {
            case .success(let user):
                self?.userRepository.saveUser(user: user)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                print("保存用户信息失败: \(error.localizedDescription)")
                                self?.logout()
                            }
                        },
                        receiveValue: { [weak self] user in
                            self?.currentUser = user
                            self?.status = .authenticated
                            self?.isLoggedIn = true
                        }
                    )
                    .store(in: &self!.cancellables)
                
            case .failure:
                self?.logout()
            }
        }
    }
    
    /// 管理员登录 - 使用手机号和密码登录到管理系统
    /// - Parameters:
    ///   - phone: 手机号/用户名
    ///   - password: 密码
    ///   - completion: 完成回调
    func adminLogin(phone: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        #if DEBUG
        print("尝试管理员登录: \(phone)")
        #endif
        
        // 调用服务器端管理员登录API
        apiService.simpleRequest(
            endpoint: "/mobile/login",
            method: "POST",
            body: ["account": phone, "password": password],  // 使用account作为参数名
            useFormData: true,  // 使用表单数据格式
            requiresAuth: false
        ) { [weak self] (result: Result<Models.AdminLoginResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        guard let ownerInfo = response.ownerInfo else {
                            completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "登录成功但未返回用户信息"])))
                            return
                        }
                        
                        #if DEBUG
                        print("管理员登录成功: \(phone)")
                        #endif
                        
                        // 构建用户对象
                        let user = User(from: ownerInfo)
                        
                        // 从响应获取token，如果响应没有提供token则生成一个临时token
                        let token = response.message ?? UUID().uuidString
                        
                        // 保存令牌
                        self?.keychainHelper.save(token, service: "auth", account: "token")
                        
                        // 保存用户信息
                        self?.userRepository.saveUser(user: user)
                            .receive(on: DispatchQueue.main)
                            .sink(
                                receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        print("保存用户信息失败: \(error.localizedDescription)")
                                    }
                                },
                                receiveValue: { [weak self] savedUser in
                                    self?.currentUser = savedUser
                                    self?.status = .authenticated
                                    self?.isLoggedIn = true
                                    completion(.success(()))
                                }
                            )
                            .store(in: &self!.cancellables)
                    } else {
                        let errorMessage = response.message ?? "登录失败"
                        #if DEBUG
                        print("管理员登录失败: \(errorMessage)")
                        #endif
                        completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    }
                case .failure(let error):
                    self?.status = .unauthenticated
                    self?.isLoggedIn = false
                    #if DEBUG
                    print("管理员登录请求失败: \(error.localizedDescription)")
                    #endif
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 验证码登录 - 使用手机号和验证码登录
    /// - Parameters:
    ///   - phone: 手机号
    ///   - code: 验证码
    ///   - completion: 完成回调
    func verifyAndLogin(phone: String, code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 使用之前的login方法实现
        login(phone: phone, code: code, completion: completion)
    }
}
