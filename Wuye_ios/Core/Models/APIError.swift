import Foundation
import Alamofire

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError(String)  // 带有错误消息的服务器错误
    case decodingError(Error)
    case notFound
    case authenticationError  // 身份验证错误，如未登录或令牌过期
    case networkError(Error)  // 网络连接错误
    case noData               // 没有数据返回
    case invalidResponse      // 无效的响应格式
    case unauthorized         // 未授权访问
    case forbidden            // 禁止访问
    case badRequest(String)   // 请求参数错误
    case timeout              // 请求超时
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求地址"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .decodingError(let error):
            return "解析数据失败: \(error.localizedDescription)"
        case .notFound:
            return "请求的资源不存在"
        case .authenticationError:
            return "身份验证失败，请重新登录"
        case .networkError(let error):
            return "网络连接错误: \(error.localizedDescription)"
        case .noData:
            return "没有接收到数据"
        case .invalidResponse:
            return "服务器返回了无效的数据格式"
        case .unauthorized:
            return "未授权访问，请登录"
        case .forbidden:
            return "您没有权限访问此资源"
        case .badRequest(let message):
            return "请求参数错误: \(message)"
        case .timeout:
            return "请求超时，请检查网络连接"
        case .unknown:
            return "发生未知错误"
        }
    }
    
    // 根据HTTP状态码创建错误
    static func fromStatusCode(_ code: Int, message: String? = nil) -> APIError {
        switch code {
        case 400:
            return .badRequest(message ?? "请求参数错误")
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 408:
            return .timeout
        case 500...599:
            return .serverError(message ?? "服务器内部错误(\(code))")
        default:
            return .unknown
        }
    }
    
    // 用于Alamofire序列化失败的方法
    static func decodingError(_ reason: AFError.ResponseSerializationFailureReason) -> APIError {
        // 使用NSError包装AFError.ResponseSerializationFailureReason
        return .decodingError(NSError(domain: "AFError.ResponseSerialization", 
                                     code: -1, 
                                     userInfo: [NSLocalizedDescriptionKey: String(describing: reason)]))
    }
}
