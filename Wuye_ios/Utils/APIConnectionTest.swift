import Foundation
import SwiftUI
import Combine
import Alamofire

/// API连接测试工具
class APIConnectionTest: ObservableObject {
    // 单例
    static let shared = APIConnectionTest()
    
    // 发布的属性
    @Published var testStatus: TestStatus = .notStarted
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    
    // 私有属性
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    // 测试状态枚举
    enum TestStatus {
        case notStarted
        case running
        case completed
        case failed
    }
    
    // 测试结果结构
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let endpoint: String
        let success: Bool
        let message: String
        let responseTime: TimeInterval
    }
    
    // 私有初始化
    private init() {}
    
    // 运行所有测试
    func runAllTests() {
        isRunning = true
        testStatus = .running
        testResults = []
        
        // 队列测试
        testPing()
            .flatMap { _ in self.testMobileLogin() }
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.testStatus = .completed
                    case .failure(let error):
                        self?.testStatus = .failed
                        self?.addResult(
                            name: "测试执行错误",
                            endpoint: "N/A",
                            success: false,
                            message: error.localizedDescription,
                            responseTime: 0
                        )
                    }
                    self?.isRunning = false
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // 测试ping接口
    private func testPing() -> AnyPublisher<Void, Error> {
        let startTime = Date()
        
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "APIConnectionTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            // 使用URLSession直接测试
            guard let url = URL(string: "\(self.getCurrentAPIBaseURL())/ping") else {
                self.addResult(
                    name: "Ping测试",
                    endpoint: "/ping",
                    success: false,
                    message: "无效的URL",
                    responseTime: 0
                )
                // 避免使用有歧义的APIError
                let error = NSError(domain: "APIConnectionTest", code: -3, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])
                promise(.failure(error))
                return
            }
            
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                let elapsedTime = Date().timeIntervalSince(startTime)
                
                if let error = error {
                    self?.addResult(
                        name: "Ping测试",
                        endpoint: "/ping",
                        success: false,
                        message: "网络错误: \(error.localizedDescription)",
                        responseTime: elapsedTime
                    )
                    promise(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.addResult(
                        name: "Ping测试",
                        endpoint: "/ping",
                        success: false,
                        message: "无效的HTTP响应",
                        responseTime: elapsedTime
                    )
                    // 使用自定义错误
                    let error = NSError(domain: "APIConnectionTest", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])
                    promise(.failure(error))
                    return
                }
                
                let success = (200...299).contains(httpResponse.statusCode)
                let message: String
                
                if success {
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        message = "成功: \(responseString)"
                    } else {
                        message = "成功: 状态码 \(httpResponse.statusCode)"
                    }
                } else {
                    message = "失败: HTTP状态码 \(httpResponse.statusCode)"
                }
                
                self?.addResult(
                    name: "Ping测试",
                    endpoint: "/ping",
                    success: success,
                    message: message,
                    responseTime: elapsedTime
                )
                
                if success {
                    promise(.success(()))
                } else {
                    // 创建自定义错误
                    let error = NSError(
                        domain: "APIConnectionTest",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP错误：\(httpResponse.statusCode)"]
                    )
                    promise(.failure(error))
                }
            }.resume()
        }.eraseToAnyPublisher()
    }
    
    // 测试移动端登录接口
    private func testMobileLogin() -> AnyPublisher<Void, Error> {
        let startTime = Date()
        
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "APIConnectionTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            // 使用测试账号进行登录尝试
            let testUsername = "testuser"
            let testPassword = "password"
            
            // 创建一个URLRequest进行手动测试
            guard var urlComponents = URLComponents(string: "\(self.getCurrentAPIBaseURL())/mobile/login") else {
                promise(.failure(NSError(domain: "APIConnectionTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
                return
            }
            
            guard let url = urlComponents.url else {
                promise(.failure(NSError(domain: "APIConnectionTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // 准备请求体
            let body: [String: Any] = ["username": testUsername, "password": testPassword]
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                promise(.failure(error))
                return
            }
            
            // 发送请求
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                let elapsedTime = Date().timeIntervalSince(startTime)
                
                if let error = error {
                    self?.addResult(
                        name: "移动端登录测试",
                        endpoint: "/mobile/login",
                        success: false,
                        message: "网络错误: \(error.localizedDescription)",
                        responseTime: elapsedTime
                    )
                    promise(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.addResult(
                        name: "移动端登录测试",
                        endpoint: "/mobile/login",
                        success: false,
                        message: "无效的HTTP响应",
                        responseTime: elapsedTime
                    )
                    promise(.failure(NSError(domain: "APIConnectionTest", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])))
                    return
                }
                
                // 处理响应数据
                if let data = data {
                    do {
                        let response = try JSONDecoder().decode(Models.AdminLoginResponse.self, from: data)
                        let success = response.success
                        let message = response.message ?? (success ? "登录成功" : "登录失败，但服务器响应正常")
                        
                        self?.addResult(
                            name: "移动端登录测试",
                            endpoint: "/mobile/login",
                            success: success,
                            message: message,
                            responseTime: elapsedTime
                        )
                        
                        promise(.success(()))
                    } catch {
                        self?.addResult(
                            name: "移动端登录测试",
                            endpoint: "/mobile/login",
                            success: false,
                            message: "解析响应失败: \(error.localizedDescription)",
                            responseTime: elapsedTime
                        )
                        promise(.failure(error))
                    }
                } else {
                    self?.addResult(
                        name: "移动端登录测试",
                        endpoint: "/mobile/login",
                        success: false,
                        message: "没有响应数据",
                        responseTime: elapsedTime
                    )
                    promise(.failure(NSError(domain: "APIConnectionTest", code: -3, userInfo: [NSLocalizedDescriptionKey: "没有响应数据"])))
                }
            }.resume()
        }.eraseToAnyPublisher()
    }
    
    // 添加测试结果
    private func addResult(name: String, endpoint: String, success: Bool, message: String, responseTime: TimeInterval) {
        DispatchQueue.main.async {
            self.testResults.append(
                TestResult(
                    name: name,
                    endpoint: endpoint,
                    success: success,
                    message: message,
                    responseTime: responseTime
                )
            )
        }
    }
    
    // 获取API当前基础URL
    func getCurrentAPIBaseURL() -> String {
        // 手动获取基础URL，避免依赖APIService的方法
        #if DEBUG
        let useLocal = UserDefaults.standard.bool(forKey: "UseLocalServer")
        let useNetworkLocal = UserDefaults.standard.bool(forKey: "UseNetworkLocalServer")
        
        if useLocal {
            if useNetworkLocal {
                return "http://192.168.1.21:8080/api"
            } else {
                return "http://127.0.0.1:8080/api"
            }
        } else {
            return "https://dev-api.wuye-app.com/api"
        }
        #else
        return "https://api.wuye-app.com/api"
        #endif
    }
}

// 注释掉重复的扩展
/*
// 扩展APIService提供公共方法获取当前BaseURL
extension APIService {
    func getCurrentBaseURL() -> String {
        #if DEBUG
        let useLocal = UserDefaults.standard.bool(forKey: "UseLocalServer")
        if useLocal {
            return "http://127.0.0.1:5000/api"
        } else {
            return "https://dev-api.wuye-app.com/api"
        }
        #else
        return "https://api.wuye-app.com/api"
        #endif
    }
}
*/ 