import Foundation
import Alamofire
import SwiftUI

// MARK: - API错误类型
// 将引用扩展为全部所需功能
extension APIError {
    // 修改为更具体的方法名，避免歧义
    static func createNetworkError(_ error: Error) -> APIError {
        return .networkError(error)  // 使用核心模型中的.networkError枚举case
    }
    
    // 使用模型中现有的类型，不要重复声明
    // static let authenticationError: APIError = .unknown  // 认证错误
    // static let noData: APIError = .unknown  // 没有数据
    // static let invalidResponse: APIError = .unknown  // 无效响应
    
    // 这里不要重复声明decodingError，因为模型中已经有了
    // 定义一个专门处理AFError的方法
    static func afResponseSerializationError(_ reason: AFError.ResponseSerializationFailureReason) -> APIError {
        return .unknown  // 使用模型中的unknown或自定义错误
    }
    
    // 不要重复声明serverError
    // static func serverError(_ message: String) -> APIError {
    //     return .unknown  // 服务器错误
    // }
}

// MARK: - API响应协议
protocol APIResponse: Decodable {
    var success: Bool { get }
    var message: String? { get }
}

// MARK: - 通用API响应结构
struct GenericResponse<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let data: T?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case data
    }
}

// MARK: - 自定义SSL评估器
class APIServerTrustManager: ServerTrustManager {
    static func defaultEvaluators(allHostsMustBeEvaluated: Bool = false) -> [String: ServerTrustEvaluating] {
        // 开发环境服务器域名
        let devServer = "dev-api.wuye-app.com"
        // 生产环境服务器域名
        let prodServer = "api.wuye-app.com"
        // 本地开发服务器
        let localServer = "localhost"
        
        var evaluators: [String: ServerTrustEvaluating] = [:]
        
        #if DEBUG
        // 在DEBUG模式下，使用禁用评估器，信任所有证书
        evaluators[devServer] = DisabledTrustEvaluator()
        evaluators[localServer] = DisabledTrustEvaluator()
        evaluators["127.0.0.1"] = DisabledTrustEvaluator()
        print("⚠️ 开发模式: 已禁用SSL证书验证，信任所有证书")
        #else
        // 在发布模式下，使用默认评估器
        evaluators[devServer] = DefaultTrustEvaluator()
        #endif
        
        // 生产环境始终使用默认评估器
        evaluators[prodServer] = DefaultTrustEvaluator()
        
        return evaluators
    }
}

// MARK: - 空响应对象
struct EmptyResponse: Codable {}

// MARK: - API 服务
class APIService {
    // 单例
    static let shared = APIService()
    private init() {}
    
    // 基础URL - 更新为后台管理系统API
    // 注意：所有baseURL已经包含了/api前缀，使用simpleRequest时，endpoint不要再加/api前缀
    // 例如：后端路由是/api/mobile/login，endpoint应该写/mobile/login而不是/api/mobile/login
    private let baseURL = "https://api.wuye-app.com/api" // 正式环境地址
    private let debugURL = "https://dev-api.wuye-app.com/api" // 开发环境地址
    private let localURL = "http://127.0.0.1:5000/api" // 本地开发地址，改为5000端口
    private let networkLocalURL = "http://192.168.1.21:5000/api" // 局域网IP地址，改为5000端口
    
    // 调试配置
    #if DEBUG
    private let enableDetailedLogs = true      // 是否启用详细日志
    private let logRequestHeaders = true       // 是否记录请求头
    private let logResponseHeaders = true      // 是否记录响应头
    private let logRequestBody = true          // 是否记录请求体
    private let logResponseBody = true         // 是否记录响应体
    private let logErrors = true               // 是否记录错误详情
    private let logTiming = true               // 是否记录请求耗时
    private let allowSelfSignedCertificates = true // 是否允许自签名证书
    #else
    private let enableDetailedLogs = false
    private let logRequestHeaders = false
    private let logResponseHeaders = false
    private let logRequestBody = false
    private let logResponseBody = false
    private let logErrors = false
    private let logTiming = false
    private let allowSelfSignedCertificates = false
    #endif
    
    // 当前环境
    #if DEBUG
    private var currentBaseURL: String { 
        let useLocal = UserDefaults.standard.bool(forKey: "UseLocalServer")
        let useNetworkLocal = UserDefaults.standard.bool(forKey: "UseNetworkLocalServer")
        
        if useLocal {
            if useNetworkLocal {
                print("🖥️ 使用局域网开发服务器: \(networkLocalURL)")
                return networkLocalURL
            } else {
                print("🖥️ 使用本地开发服务器: \(localURL)")
                return localURL
            }
        } else {
            print("🌐 使用开发环境服务器: \(debugURL)")
            return debugURL
        }
    }
    #else
    private var currentBaseURL: String { return baseURL }
    #endif
    
    // 会话管理器 - 使用Wuye_iosApp中定义的自定义会话
    private var session: Session {
        return Wuye_iosApp.customSession
    }
    
    // MARK: - 请求日志相关方法
    private func printRequestDivider() {
        print("\n——————————— 🚀 API REQUEST ———————————")
    }
    
    private func printResponseDivider() {
        print("——————————— 🏁 API RESPONSE ——————————\n")
    }
    
    // 修改logResponseData方法，明确Encodable约束
    private func logResponseData<T>(_ data: T) where T: Encodable {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📥 响应数据:")
                print(jsonString)
            }
        } catch {
            print("📥 响应数据: (无法序列化)")
        }
    }
    
    // 为Data类型添加一个专用的logResponseData方法
    private func logResponseData(_ data: Data) {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []),
           let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📥 响应数据:")
            print(jsonString)
        } else if let str = String(data: data, encoding: .utf8) {
            print("📥 响应文本:")
            print(str)
        } else {
            print("📥 响应数据: (无法解析的二进制数据)")
        }
    }
    
    private func logNetworkError(_ error: Error) {
        if let afError = error.asAFError {
            // 记录Alamofire错误
            print("🔍 Alamofire错误类型: \(type(of: afError))")
            
            if let urlError = afError.underlyingError as? URLError {
                print("   底层URL错误: \(urlError.localizedDescription)")
                print("   错误代码: \(urlError.code.rawValue)")
                print("   错误域: \(urlError.errorCode)")
            }
            
            switch afError {
            case .sessionTaskFailed(let error):
                print("   会话任务失败: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   NSError域: \(nsError.domain), 代码: \(nsError.code)")
                    print("   用户信息: \(nsError.userInfo)")
                }
            case .responseValidationFailed(let reason):
                print("   响应验证失败: \(reason)")
                if case .unacceptableStatusCode(let code) = reason {
                    print("   状态码: \(code)")
                }
            case .responseSerializationFailed(let reason):
                print("   响应序列化失败: \(reason)")
                if case .jsonSerializationFailed(let error) = reason {
                    print("   JSON序列化错误: \(error.localizedDescription)")
                } else if case .decodingFailed(let error) = reason {
                    print("   解码错误: \(error.localizedDescription)")
                    // 打印解码错误的详细信息
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("   数据损坏: \(context.debugDescription)")
                            print("   编码路径: \(context.codingPath)")
                        case .keyNotFound(let key, let context):
                            print("   找不到键: \(key.stringValue)")
                            print("   编码路径: \(context.codingPath)")
                            print("   描述: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("   类型不匹配: 预期类型 \(type)")
                            print("   编码路径: \(context.codingPath)")
                            print("   描述: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("   未找到值: 预期类型 \(type)")
                            print("   编码路径: \(context.codingPath)")
                            print("   描述: \(context.debugDescription)")
                        @unknown default:
                            print("   未知的解码错误")
                        }
                    }
                }
            default:
                print("   其他Alamofire错误: \(afError.localizedDescription)")
                print("   错误详情: \(String(describing: afError))")
            }
        } else {
            // 记录其他错误
            print("🔍 错误类型: \(type(of: error))")
            print("   描述: \(error.localizedDescription)")
            
            // 检查是否是SwiftUI线程发布错误
            if error.localizedDescription.contains("Publishing changes from background threads is not allowed") {
                print("⚠️ SwiftUI线程错误: 在后台线程发布UI更新")
                print("   解决方案: 使用 DispatchQueue.main.async 或 .receive(on: DispatchQueue.main) 确保在主线程更新UI")
                
                // 打印当前堆栈跟踪以帮助定位问题
                let stackTrace = Thread.callStackSymbols
                print("   调用堆栈:")
                for (index, symbol) in stackTrace.enumerated() {
                    print("     [\(index)] \(symbol)")
                }
            }
            
            // 扩展NSError信息
            if let nsError = error as NSError? {
                print("   NSError域: \(nsError.domain)")
                print("   错误代码: \(nsError.code)")
                print("   用户信息: \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - 发送请求
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        encoding: ParameterEncoding = JSONEncoding.default,
        requiresAuth: Bool = true,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        // 构建URL
        let urlString = currentBaseURL + endpoint
        
        // 准备请求头
        var requestHeaders = headers ?? HTTPHeaders()
        if requiresAuth {
            if let token = KeychainHelper.shared.get(service: "auth", account: "token") {
                requestHeaders.add(name: "Authorization", value: "Bearer \(token)")
            } else {
                completion(Result.failure(.unauthorized))
                return
            }
        }
        
        // 记录请求开始时间
        let startTime = Date()
        
        // 记录请求信息（开发环境）
        #if DEBUG
        if enableDetailedLogs {
            printRequestDivider()
            print("📡 API请求: \(method.rawValue) \(urlString)")
            
            if logRequestHeaders && !requestHeaders.isEmpty {
                print("📋 请求头:")
                requestHeaders.forEach { header in
                    let value = header.name.lowercased() == "authorization" ? 
                                "Bearer ********" : header.value
                    print("   \(header.name): \(value)")
                }
            }
            
            if logRequestBody, let params = parameters, !params.isEmpty {
                print("📦 请求参数:")
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    } else {
                        print("   \(params)")
                    }
                } catch {
                    print("   \(params)")
                }
            }
        }
        #endif
        
        // 发起请求
        session.request(
            urlString,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: requestHeaders
        )
        .validate()
        .responseDecodable(of: GenericResponse<T>.self) { response in
            // 计算请求耗时
            let requestTime = Date().timeIntervalSince(startTime)
            
            #if DEBUG
            if self.enableDetailedLogs && self.logTiming {
                print("⏱️ 请求耗时: \(String(format: "%.4f", requestTime))秒")
            }
            #endif
            
            // 处理响应
            switch response.result {
            case .success(let genericResponse):
                if genericResponse.success {
                    if let data = genericResponse.data {
                        // 记录响应信息
                        #if DEBUG
                        if self.enableDetailedLogs && self.logResponseBody {
                            print("✅ API响应成功: \(urlString)")
                            // 确保data符合Encodable协议
                            if let encodableData = data as? Encodable {
                                self.logResponseData(encodableData)
                            } else {
                                print("📥 响应数据: (无法序列化，类型不符合Encodable协议)")
                            }
                        }
                        #endif
                        
                        completion(Result.success(data))
                    } else {
                        // 有些API可能不返回data字段，而是空结构
                        if let emptyObject = EmptyResponse() as? T {
                            #if DEBUG
                            if self.enableDetailedLogs && self.logResponseBody {
                                print("✅ API响应成功: \(urlString) (空数据)")
                            }
                            #endif
                            
                            completion(Result.success(emptyObject))
                        } else {
                            #if DEBUG
                            if self.enableDetailedLogs && self.logErrors {
                                print("❌ API响应错误: 没有数据")
                            }
                            #endif
                            
                            completion(Result.failure(.noData))
                        }
                    }
                } else {
                    #if DEBUG
                    if self.enableDetailedLogs && self.logErrors {
                        print("❌ API响应错误: \(genericResponse.message ?? "未知服务器错误")")
                    }
                    #endif
                    
                    completion(Result.failure(.serverError(genericResponse.message ?? "未知服务器错误")))
                }
                
            case .failure(let error):
                #if DEBUG
                if self.enableDetailedLogs && self.logErrors {
                    print("❌ API请求失败: \(urlString)")
                    print("   错误: \(error.localizedDescription)")
                    
                    if let data = response.data, let str = String(data: data, encoding: .utf8) {
                        print("   响应数据: \(str)")
                    }
                    
                    if let statusCode = response.response?.statusCode {
                        print("   状态码: \(statusCode)")
                    }
                    
                    // 详细记录网络错误
                    self.logNetworkError(error)
                }
                #endif
                
                if let afError = error.asAFError {
                    switch afError {
                    case .responseValidationFailed(let reason):
                        if case .unacceptableStatusCode(let code) = reason, code == 401 {
                            #if DEBUG
                            if self.enableDetailedLogs && self.logErrors {
                                print("   认证失败 (401)")
                            }
                            #endif
                            
                            completion(Result.failure(.unauthorized))
                        } else {
                            #if DEBUG
                            if self.enableDetailedLogs && self.logErrors {
                                print("   响应验证失败: \(reason)")
                            }
                            #endif
                            
                            completion(Result.failure(.invalidResponse))
                        }
                    case .responseSerializationFailed(let reason):
                        #if DEBUG
                        if self.enableDetailedLogs && self.logErrors {
                            print("   响应序列化失败: \(reason)")
                            if let underlyingError = afError.underlyingError {
                                print("   底层错误: \(underlyingError)")
                            }
                            
                            // 尝试直接解析响应数据
                            if let data = response.data, let str = String(data: data, encoding: .utf8) {
                                print("   原始响应数据:")
                                print(str)
                                
                                // 尝试解析为普通JSON
                                do {
                                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                                        print("   JSON解析结果:")
                                        print(json)
                                    }
                                } catch {
                                    print("   无法解析为JSON: \(error)")
                                }
                            }
                        }
                        #endif
                        
                        // 使用专门处理AFError的方法
                        completion(Result.failure(.decodingError(reason)))
                    case .sessionTaskFailed(let error):
                        #if DEBUG
                        if self.enableDetailedLogs && self.logErrors {
                            if let urlError = error as? URLError {
                                if urlError.code == .secureConnectionFailed || 
                                   urlError.code.rawValue == -1200 {  // -1200 是常见的SSL错误代码
                                    print("   SSL连接错误，可能是证书问题")
                                }
                            }
                        }
                        #endif
                        
                        let apiError: APIError = .createNetworkError(error)
                        completion(Result.failure(apiError))
                    default:
                        #if DEBUG
                        if self.enableDetailedLogs && self.logErrors {
                            print("   Alamofire错误: \(afError)")
                        }
                        #endif
                        
                        let apiError: APIError = .createNetworkError(error)
                        completion(Result.failure(apiError))
                    }
                } else {
                    #if DEBUG
                    if self.enableDetailedLogs && self.logErrors {
                        print("   非Alamofire错误: \(error)")
                    }
                    #endif
                    
                    let apiError: APIError = .createNetworkError(error)
                    completion(Result.failure(apiError))
                }
            }
            
            #if DEBUG
            if self.enableDetailedLogs {
                self.printResponseDivider()
            }
            #endif
        }
    }
    
    // 简单请求方法 - 直接使用URLSession
    func simpleRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        useFormData: Bool = false,
        requiresAuth: Bool = true,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // 构建URL
        let urlString = currentBaseURL + endpoint
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // 添加认证头
        if requiresAuth, let token = KeychainHelper.shared.get(service: "auth", account: "token") {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 添加请求体
        if let body = body {
            if useFormData {
                // 使用表单格式发送数据
                var formComponents = URLComponents()
                var queryItems = [URLQueryItem]()
                
                for (key, value) in body {
                    let stringValue = "\(value)"
                    queryItems.append(URLQueryItem(name: key, value: stringValue))
                }
                
                formComponents.queryItems = queryItems
                request.httpBody = formComponents.percentEncodedQuery?.data(using: .utf8)
                request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                
                #if DEBUG
                if enableDetailedLogs {
                    print("发送表单数据: \(formComponents.percentEncodedQuery ?? "")")
                }
                #endif
            } else {
                // 使用JSON格式发送数据
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                } catch {
                    completion(.failure(error))
                    return
                }
            }
        }
        
        // 记录请求
        #if DEBUG
        if enableDetailedLogs {
            print("\n——— Simple API Request ———")
            print("URL: \(urlString)")
            print("Method: \(method)")
            if let body = body {
                print("Body: \(body)")
            }
            
            if requiresAuth {
                print("Authorization: Bearer ********")
            }
        }
        #endif
        
        // 发送请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 检查是否有错误
            if let error = error {
                #if DEBUG
                if self.enableDetailedLogs && self.logErrors {
                    print("❌ 简单请求失败: \(urlString)")
                    print("   错误: \(error.localizedDescription)")
                }
                #endif
                
                DispatchQueue.main.async {
                    completion(.failure(APIError.createNetworkError(error)))
                }
                return
            }
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])))
                }
                return
            }
            
            #if DEBUG
            if self.enableDetailedLogs {
                print("🔄 HTTP状态码: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📦 响应内容: \(responseString)")
                }
            }
            #endif
            
            // 检查状态码
            guard 200..<300 ~= httpResponse.statusCode else {
                DispatchQueue.main.async {
                    let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                }
                return
            }
            
            // 检查数据
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "没有数据"])))
                }
                return
            }
            
            // 尝试解析数据
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                #if DEBUG
                if self.enableDetailedLogs && self.logErrors {
                    print("❌ 解析响应失败: \(error.localizedDescription)")
                    if let str = String(data: data, encoding: .utf8) {
                        print("Raw response: \(str)")
                    }
                }
                #endif
                
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            
            #if DEBUG
            if self.enableDetailedLogs {
                print("——— Simple API Response ———\n")
            }
            #endif
        }.resume()
    }
    
    // 简单请求方法 - 返回Any类型的数据，用于处理未知结构的响应
    func simpleRequest(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true,
        completion: @escaping (Result<Any, Error>) -> Void
    ) {
        // 构建URL
        let urlString = currentBaseURL + endpoint
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // 添加认证头
        if requiresAuth, let token = KeychainHelper.shared.get(service: "auth", account: "token") {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 添加请求体
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        // 记录请求
        #if DEBUG
        if enableDetailedLogs {
            print("\n——— Simple API Request (Any) ———")
            print("URL: \(urlString)")
            print("Method: \(method)")
            if let body = body {
                print("Body: \(body)")
            }
            
            if requiresAuth {
                print("Authorization: Bearer ********")
            }
        }
        #endif
        
        // 发送请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 检查是否有错误
            if let error = error {
                #if DEBUG
                if self.enableDetailedLogs && self.logErrors {
                    print("❌ 简单请求失败: \(urlString)")
                    print("   错误: \(error.localizedDescription)")
                }
                #endif
                
                DispatchQueue.main.async {
                    completion(.failure(APIError.createNetworkError(error)))
                }
                return
            }
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])))
                }
                return
            }
            
            // 检查状态码
            guard 200..<300 ~= httpResponse.statusCode else {
                DispatchQueue.main.async {
                    let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                }
                return
            }
            
            // 检查数据
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "没有数据"])))
                }
                return
            }
            
            // 尝试将数据解析为JSON对象
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                DispatchQueue.main.async {
                    completion(.success(jsonObject))
                }
            } catch {
                #if DEBUG
                if self.enableDetailedLogs && self.logErrors {
                    print("❌ 解析JSON失败: \(error.localizedDescription)")
                    if let str = String(data: data, encoding: .utf8) {
                        print("Raw response: \(str)")
                    }
                }
                #endif
                
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            
            #if DEBUG
            if self.enableDetailedLogs {
                print("——— Simple API Response (Any) ———\n")
            }
            #endif
        }.resume()
    }
    
    // MARK: - 上传文件
    func uploadFile(
        endpoint: String,
        fileURL: URL,
        fieldName: String = "file",
        fileName: String? = nil,
        mimeType: String = "application/octet-stream",
        parameters: [String: String] = [:],
        requiresAuth: Bool = true,
        completion: @escaping (Result<Data, APIError>) -> Void
    ) {
        // 构建URL
        let urlString = currentBaseURL + endpoint
        
        // 准备请求头
        var requestHeaders = HTTPHeaders()
        
        // 添加认证头
        if requiresAuth {
            if let token = KeychainHelper.shared.get(service: "auth", account: "token") {
                requestHeaders.add(name: "Authorization", value: "Bearer \(token)")
            } else {
                completion(Result.failure(.unauthorized))
                return
            }
        }
        
        // 记录请求开始时间
        let startTime = Date()
        
        // 记录请求信息（开发环境）
        #if DEBUG
        if enableDetailedLogs {
            printRequestDivider()
            print("📤 上传文件: \(urlString)")
            print("📎 文件路径: \(fileURL.path)")
            print("📄 文件名: \(fileName ?? fileURL.lastPathComponent)")
            print("🔠 MIME类型: \(mimeType)")
            
            if !parameters.isEmpty {
                print("📦 附加参数:")
                parameters.forEach { key, value in
                    print("   \(key): \(value)")
                }
            }
        }
        #endif
        
        // 开始上传
        session.upload(
            multipartFormData: { formData in
                // 添加文件
                formData.append(
                    fileURL,
                    withName: fieldName,
                    fileName: fileName ?? fileURL.lastPathComponent,
                    mimeType: mimeType
                )
                
                // 添加其他参数
                for (key, value) in parameters {
                    if let data = value.data(using: .utf8) {
                        formData.append(data, withName: key)
                    }
                }
            },
            to: urlString,
            headers: requestHeaders
        )
        .validate()
        .responseData { response in
            // 计算上传耗时
            let uploadTime = Date().timeIntervalSince(startTime)
            
            #if DEBUG
            if self.enableDetailedLogs && self.logTiming {
                print("⏱️ 上传耗时: \(String(format: "%.4f", uploadTime))秒")
            }
            #endif
            
            switch response.result {
            case .success(let data):
                #if DEBUG
                if self.enableDetailedLogs && self.logResponseBody {
                    print("✅ 文件上传成功: \(urlString)")
                    // 直接使用Data版本的logResponseData方法
                    self.logResponseData(data)
                }
                #endif
                
                completion(Result.success(data))
                
            case .failure(let error):
                #if DEBUG
                if self.enableDetailedLogs && self.logErrors {
                    print("❌ 文件上传失败: \(urlString)")
                    print("   错误: \(error.localizedDescription)")
                    
                    if let data = response.data, let str = String(data: data, encoding: .utf8) {
                        print("   响应数据: \(str)")
                    }
                    
                    if let statusCode = response.response?.statusCode {
                        print("   状态码: \(statusCode)")
                    }
                }
                #endif
                
                let apiError: APIError = .createNetworkError(error)
                completion(Result.failure(apiError))
            }
            
            #if DEBUG
            if self.enableDetailedLogs {
                self.printResponseDivider()
            }
            #endif
        }
    }
    
    // 公开获取baseURL的方法，供API测试工具使用
    func getCurrentBaseURL() -> String {
        #if DEBUG
        let useLocal = UserDefaults.standard.bool(forKey: "UseLocalServer")
        let useNetworkLocal = UserDefaults.standard.bool(forKey: "UseNetworkLocalServer")
        
        if useLocal {
            if useNetworkLocal {
                return networkLocalURL
            } else {
                return localURL
            }
        } else {
            return debugURL
        }
        #else
        return baseURL
        #endif
    }
}

/*
// 已移至 APIEventMonitor.swift
// MARK: - 自定义事件监听器参考实现
#if DEBUG
final class _APIEventMonitor: EventMonitor {
    func requestDidResume(_ request: Request) {
        // 请求开始
        let allHeaders = request.request?.allHTTPHeaderFields ?? [:]
        let requestDescription = request.description
        
        // 事件监视器部分的日志可以在这里添加特定的细节
        // 修复：Request没有isUploadRequest成员的问题
        if let uploadRequest = request as? UploadRequest {
            // 上传请求特殊处理
            print("📤 开始上传请求: \(requestDescription)")
        }
    }
    
    func requestDidFinish(_ request: Request) {
        // 请求结束
        let requestDuration = request.metrics?.taskInterval?.duration ?? 0
        
        // 网络指标记录
        if let metrics = request.metrics {
            // 可以在这里添加详细的网络性能指标记录
            if let taskInterval = metrics.taskInterval {
                print("🔄 请求完成: \(String(format: "%.4f", taskInterval.duration))秒")
            }
            
            // 添加传输指标记录
            print("📊 网络传输指标: \(metrics.transactionMetrics.count)项")
            
            // 显示请求开始和结束时间
            if let firstTransaction = metrics.transactionMetrics.first,
               let lastTransaction = metrics.transactionMetrics.last {
                
                if let requestStartDate = firstTransaction.requestStartDate,
                   let responseEndDate = lastTransaction.responseEndDate {
                    let totalTime = responseEndDate.timeIntervalSince(requestStartDate)
                    print("⏱️ 总请求耗时: \(String(format: "%.4f", totalTime))秒")
                }
                
                // 打印网络协议信息
                if let networkProtocol = firstTransaction.networkProtocolName {
                    print("🌐 网络协议: \(networkProtocol)")
                }
            }
        }
    }
    
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        // 请求解析响应
        if let statusCode = response.response?.statusCode {
            print("📊 HTTP状态码: \(statusCode)")
        }
    }
}
#endif
*/
