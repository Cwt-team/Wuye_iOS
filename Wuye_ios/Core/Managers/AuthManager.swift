import Foundation
import Combine
import Network

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

// MARK: - 认证错误
enum AuthError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
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
    private var cancellables = Set<AnyCancellable>()
    private let userRepository: UserRepositoryProtocol
    
    // API配置
    private let serverIP = "8.138.26.199"  // 服务器IP地址
    private let serverPort = "5000"        // 服务器端口
    private var baseURL: String {
        return "http://\(serverIP):\(serverPort)"
    }
    
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
        status = .verifying
        
        guard let token = keychainHelper.get(service: "auth", account: "token") else {
            setUnauthenticatedState()
            return
        }
        
        userRepository.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.logout()
                    }
                },
                receiveValue: { [weak self] user in
                    if let user = user {
                        self?.setAuthenticatedState(user: user)
                    } else {
                        self?.setUnauthenticatedState()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// 登出
    func logout() {
        keychainHelper.delete(service: "auth", account: "token")
        setUnauthenticatedState()
    }
    
    /// 账号密码登录
    func loginWithPassword(phone_number: String, password: String, completion: @escaping (Bool) -> Void) {
        // 配置服务器地址
        #if DEBUG
        let serverConfig = (
            ip: "8.138.26.199",
            port: "5000",
            scheme: "http"
        )
        #else
        let serverConfig = (
            ip: "your.production.server",
            port: "443",
            scheme: "https"
        )
        #endif
        
        let baseURL = "\(serverConfig.scheme)://\(serverConfig.ip):\(serverConfig.port)"
        
        guard let url = URL(string: "\(baseURL)/api/mobile/login") else {
            print("[AuthManager] 无效的URL")
            completion(false)
            return
        }
        
        // 配置请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        
        // 设置请求头
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        // 构建请求体
        let bodyString = "phone_number=\(phone_number)&password=\(password)"
        request.httpBody = bodyString.data(using: .utf8)
        
        // 配置URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.connectionProxyDictionary = [:]  // 禁用代理
        
        // 检查网络连接
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("[AuthManager] 网络连接正常")
                // 网络正常，执行请求
                self?.executeRequest(
                    request: request,
                    config: config,
                    baseURL: baseURL,
                    password: password,
                    completion: completion
                )
            } else {
                print("[AuthManager] 网络连接不可用")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
            monitor.cancel()
        }
        
        monitor.start(queue: queue)
    }
    
    // MARK: - 私有方法
    
    private func executeRequest(
        request: URLRequest,
        config: URLSessionConfiguration,
        baseURL: String,
        password: String,
        completion: @escaping (Bool) -> Void,
        attempt: Int = 1,
        maxAttempts: Int = 3
    ) {
        print("[AuthManager] 尝试登录 (第 \(attempt) 次，共 \(maxAttempts) 次)")
        print("[AuthManager] 正在连接服务器: \(baseURL)")
        
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("[AuthManager] 网络错误: \(error.localizedDescription)")
                
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        print("[AuthManager] 连接超时，请检查网络连接和服务器地址")
                    case .cannotConnectToHost:
                        print("[AuthManager] 无法连接到服务器，请确认服务器是否在运行")
                    case .networkConnectionLost:
                        print("[AuthManager] 网络连接断开")
                    default:
                        print("[AuthManager] 网络错误代码: \(urlError.code)")
                    }
                    
                    // 如果还有重试机会，则重试
                    if attempt < maxAttempts {
                        print("[AuthManager] 2秒后重试...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self?.executeRequest(
                                request: request,
                                config: config,
                                baseURL: baseURL,
                                password: password,
                                completion: completion,
                                attempt: attempt + 1,
                                maxAttempts: maxAttempts
                            )
                        }
                        return
                    }
                }
                
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // 检查HTTP响应
            if let httpResponse = response as? HTTPURLResponse {
                print("[AuthManager] HTTP状态码: \(httpResponse.statusCode)")
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("[AuthManager] 服务器错误: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
            }
            
            guard let data = data else {
                print("[AuthManager] 未收到数据")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // 打印响应数据用于调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("[AuthManager] 服务器响应: \(responseString)")
            }
            
            do {
                let response = try JSONDecoder().decode(LoginResponse.self, from: data)
                DispatchQueue.main.async {
                    if response.success, let info = response.ownerInfo {
                        let user = User(
                            id: Int64(info.id) ?? 0,
                            username: info.account,
                            password: password,
                            phone: info.phoneNumber,
                            email: "",
                            address: ""
                        )
                        self?.currentUser = user
                        self?.status = .authenticated
                        self?.isLoggedIn = true
                        print("[AuthManager] 登录成功")
                        completion(true)
                    } else {
                        print("[AuthManager] 登录失败: \(response.message ?? "未知错误")")
                        self?.status = .unauthenticated
                        self?.isLoggedIn = false
                        completion(false)
                    }
                }
            } catch {
                print("[AuthManager] 数据解析错误: \(error)")
                DispatchQueue.main.async {
                    self?.status = .unauthenticated
                    self?.isLoggedIn = false
                    completion(false)
                }
            }
        }
        task.resume()
    }
    
    // MARK: - 私有辅助方法
    
    private func setAuthenticatedState(user: User) {
        currentUser = user
        status = .authenticated
        isLoggedIn = true
    }
    
    private func setUnauthenticatedState() {
        status = .unauthenticated
        currentUser = nil
        isLoggedIn = false
    }
}

