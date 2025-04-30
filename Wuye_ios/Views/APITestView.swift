import SwiftUI
import Combine

struct APITestView: View {
    // API设置
    @State private var endpoint: String = "/mobile/login"
    @State private var method: String = "POST"
    @State private var requiresAuth: Bool = false
    @State private var requestBody: String = "{\"username\": \"admin\", \"password\": \"admin123\"}"
    
    // 状态
    @State private var isLoading: Bool = false
    @State private var response: String = ""
    @State private var error: String = ""
    @State private var statusCode: Int? = nil
    @State private var requestTime: TimeInterval = 0
    @State private var showResponseTime: Bool = false
    @State private var showDetailedError: Bool = false
    
    // 数据库测试状态
    @State private var dbTestMessage: String = ""
    @State private var dbTestSuccess: Bool = false
    @State private var isTestingDB: Bool = false
    
    // 调试设置
    @State private var useLocalServer: Bool = true
    @State private var useNetworkLocalServer: Bool = true
    
    // 环境设置
    @Environment(\.colorScheme) var colorScheme
    private let apiService = APIService.shared
    
    var body: some View {
        NavigationView {
            Form {
                // API配置部分
                Section(header: Text("API 配置")) {
                    TextField("终端点", text: $endpoint)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Picker("请求方法", selection: $method) {
                        Text("GET").tag("GET")
                        Text("POST").tag("POST")
                        Text("PUT").tag("PUT")
                        Text("DELETE").tag("DELETE")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Toggle("需要认证", isOn: $requiresAuth)
                }
                
                // 请求体
                Section(header: Text("请求体 (JSON)")) {
                    TextEditor(text: $requestBody)
                        .frame(height: 100)
                        .font(.system(size: 14, design: .monospaced))
                }
                
                // 服务器设置
                Section(header: Text("服务器设置")) {
                    Toggle("使用本地服务器", isOn: $useLocalServer)
                        .onChange(of: useLocalServer) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "UseLocalServer")
                        }
                    
                    if useLocalServer {
                        Toggle("使用局域网IP", isOn: $useNetworkLocalServer)
                            .onChange(of: useNetworkLocalServer) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "UseNetworkLocalServer")
                            }
                    }
                    
                    // 显示当前基础URL
                    VStack(alignment: .leading) {
                        Text("当前服务器地址:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(apiService.getCurrentBaseURL())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.blue)
                            .textSelection(.enabled)
                    }
                }
                
                // 数据库测试按钮
                Section(header: Text("本地数据库")) {
                    Button(action: testDatabaseConnection) {
                        if isTestingDB {
                            HStack {
                                Text("测试中...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("测试数据库连接")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .disabled(isTestingDB)
                    
                    Text("测试结果将在Debug控制台中显示")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !dbTestMessage.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("数据库测试结果:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Image(systemName: dbTestSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(dbTestSuccess ? .green : .red)
                                
                                Text(dbTestSuccess ? "连接成功" : "连接失败")
                                    .font(.caption)
                                    .foregroundColor(dbTestSuccess ? .green : .red)
                            }
                            
                            Text(dbTestMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 发送请求按钮
                Section {
                    Button(action: sendRequest) {
                        if isLoading {
                            HStack {
                                Text("发送中...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("发送请求")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(BorderedButtonStyle())
                }
                
                // 响应部分
                if !response.isEmpty || !error.isEmpty || statusCode != nil {
                    Section(header: Text("响应")) {
                        if showResponseTime {
                            Text("请求耗时: \(String(format: "%.3f", requestTime))秒")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let statusCode = statusCode {
                            HStack {
                                Text("状态码:")
                                Spacer()
                                Text("\(statusCode)")
                                    .foregroundColor(statusCode >= 200 && statusCode < 300 ? .green : .red)
                                    .bold()
                            }
                        }
                        
                        if !error.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("错误:")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showDetailedError.toggle()
                                    }) {
                                        Text(showDetailedError ? "隐藏详情" : "查看详情")
                                            .font(.caption)
                                    }
                                }
                                
                                if showDetailedError {
                                    ScrollView {
                                        Text(error)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.red)
                                            .textSelection(.enabled)
                                            .padding(.vertical, 4)
                                    }
                                    .frame(height: 200)
                                } else {
                                    Text(error.split(separator: "\n").first ?? "")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.red)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        
                        if !response.isEmpty {
                            VStack(alignment: .leading) {
                                Text("内容:")
                                    .font(.headline)
                                
                                ScrollView {
                                    Text(response)
                                        .font(.system(size: 12, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding(.vertical, 4)
                                }
                                .frame(height: 300)
                                .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .navigationTitle("API 测试工具")
            .navigationBarItems(trailing:
                Button(action: {
                    response = ""
                    error = ""
                    statusCode = nil
                    showResponseTime = false
                }) {
                    Image(systemName: "trash")
                }
                .disabled(response.isEmpty && error.isEmpty && statusCode == nil)
            )
        }
        .onAppear {
            // 读取UserDefaults设置
            useLocalServer = UserDefaults.standard.bool(forKey: "UseLocalServer")
            useNetworkLocalServer = UserDefaults.standard.bool(forKey: "UseNetworkLocalServer")
        }
    }
    
    private func sendRequest() {
        isLoading = true
        response = ""
        error = ""
        statusCode = nil
        showResponseTime = false
        
        // 记录开始时间
        let startTime = Date()
        
        // 解析请求体
        var parameters: [String: Any]?
        if !requestBody.isEmpty && method != "GET" {
            do {
                if let data = requestBody.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    parameters = json
                }
            } catch {
                self.error = "请求体JSON解析错误: \(error.localizedDescription)"
                isLoading = false
                return
            }
        }
        
        // 发送请求
        print("📣 测试API请求: \(method) \(endpoint)")
        print("📣 参数: \(parameters ?? [:])")
        
        // 创建取消令牌
        let apiOperation = APIOperation()
        DispatchQueue.global(qos: .userInitiated).async {
            // 使用通用API调用
            apiService.simpleRequest(
                endpoint: endpoint,
                method: method,
                body: parameters,
                requiresAuth: requiresAuth
            ) { (result: Result<Any, Error>) in
                // 计算请求耗时
                let elapsed = Date().timeIntervalSince(startTime)
                
                // 更新UI，确保在主线程
                DispatchQueue.main.async {
                    isLoading = false
                    requestTime = elapsed
                    showResponseTime = true
                    
                    switch result {
                    case .success(let data):
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                            if let jsonString = String(data: jsonData, encoding: .utf8) {
                                self.response = jsonString
                                print("📣 API测试响应: \(jsonString)")
                            } else {
                                self.response = "无法将响应转换为字符串"
                            }
                            self.statusCode = 200  // 假设成功响应
                        } catch {
                            self.response = "响应格式化错误: \(error.localizedDescription)"
                            print("📣 API测试格式化错误: \(error)")
                        }
                        
                    case .failure(let error):
                        // 详细错误记录
                        var errorMessage = "错误: \(error.localizedDescription)"
                        
                        if let apiError = error as? APIError {
                            switch apiError {
                            case .networkError(let underlyingError):
                                errorMessage += "\n\n网络错误详情: \(underlyingError.localizedDescription)"
                                
                                if let nsError = underlyingError as NSError? {
                                    errorMessage += "\n域: \(nsError.domain)"
                                    errorMessage += "\n代码: \(nsError.code)"
                                    
                                    if !nsError.userInfo.isEmpty {
                                        errorMessage += "\n\n用户信息:"
                                        for (key, value) in nsError.userInfo {
                                            errorMessage += "\n\(key): \(value)"
                                        }
                                    }
                                }
                                
                                // 检查是否是线程错误
                                if underlyingError.localizedDescription.contains("Publishing changes from background threads is not allowed") {
                                    errorMessage += "\n\n⚠️ SwiftUI线程错误: 请确保更新UI状态的代码在主线程执行。"
                                    errorMessage += "\n解决方案: 使用 DispatchQueue.main.async { } 或 .receive(on: DispatchQueue.main)"
                                }
                                
                            case .decodingError(let reason):
                                errorMessage += "\n\n解码错误: \(reason)"
                                
                            case .serverError(let message):
                                errorMessage += "\n\n服务器错误: \(message)"
                                
                            case .unauthorized:
                                errorMessage += "\n\n认证失败: 请确保您已登录或提供了有效的认证令牌"
                                
                            case .invalidResponse:
                                errorMessage += "\n\n无效响应: 服务器返回了无法处理的数据格式"
                                
                            case .noData:
                                errorMessage += "\n\n没有数据: 服务器没有返回任何数据"
                                
                            case .unknown:
                                errorMessage += "\n\n未知错误"
                                
                            case .invalidURL:
                                errorMessage += "\n\n无效的URL: 请检查请求地址是否正确"
                                
                            case .notFound:
                                errorMessage += "\n\n请求的资源不存在"
                                
                            case .authenticationError:
                                errorMessage += "\n\n身份验证失败，请重新登录"
                                
                            case .forbidden:
                                errorMessage += "\n\n您没有权限访问此资源"
                                
                            case .badRequest(let message):
                                errorMessage += "\n\n请求参数错误: \(message)"
                                
                            case .timeout:
                                errorMessage += "\n\n请求超时，请检查网络连接"
                            }
                        }
                        
                        // 记录线程信息
                        if Thread.isMainThread {
                            errorMessage += "\n\n当前在主线程处理错误"
                        } else {
                            errorMessage += "\n\n⚠️ 当前在后台线程处理错误，这可能导致UI更新问题"
                        }
                        
                        self.error = errorMessage
                        print("📣 API测试错误: \(errorMessage)")
                        
                        // 尝试获取HTTP状态码
                        if let urlResponse = apiOperation.response as? HTTPURLResponse {
                            self.statusCode = urlResponse.statusCode
                        } else if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain {
                            // 对于网络错误，使用NSError代码
                            self.statusCode = nsError.code
                        }
                    }
                }
            }
        }
    }
    
    private func testDatabaseConnection() {
        // 设置状态
        isTestingDB = true
        dbTestMessage = ""
        dbTestSuccess = false
        
        // 添加震动反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 在后台线程执行数据库测试
        DispatchQueue.global(qos: .userInitiated).async {
            // 捕获控制台输出的临时解决方案
            var capturedOutput = ""
            let startTime = Date()
            
            // 调用DBManager的测试方法
            DBManager.shared.testDatabaseConnection()
            
            // 延迟一点时间确保测试完成
            let elapsedTime = Date().timeIntervalSince(startTime)
            let message: String
            let success: Bool
            
            if let dbPath = DBManager.shared.getDatabasePath() {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: dbPath) {
                    success = true
                    message = "数据库文件存在于: \(dbPath)"
                } else {
                    success = false
                    message = "数据库文件不存在！路径: \(dbPath)"
                }
            } else {
                success = false
                message = "无法获取数据库路径"
            }
            
            // 更新UI必须在主线程
            DispatchQueue.main.async {
                isTestingDB = false
                dbTestSuccess = success
                dbTestMessage = message
            }
        }
    }
}

// 用于跟踪请求响应的操作类
class APIOperation {
    var response: URLResponse?
    
    init() {}
}

struct APITestView_Previews: PreviewProvider {
    static var previews: some View {
        APITestView()
    }
} 