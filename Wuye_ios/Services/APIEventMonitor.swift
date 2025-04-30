import Foundation
import Alamofire

/// 用于监控和记录Alamofire网络请求事件的监视器
#if DEBUG
final class APIEventMonitor: EventMonitor {
    /// 请求开始时调用
    func requestDidResume(_ request: Request) {
        // 请求开始
        let allHeaders = request.request?.allHTTPHeaderFields ?? [:]
        let requestDescription = request.description
        
        if let uploadRequest = request as? UploadRequest {
            // 上传请求特殊处理
            print("📤 开始上传请求: \(requestDescription)")
        } else {
            print("📡 开始请求: \(requestDescription)")
        }
    }
    
    /// 请求完成时调用
    func requestDidFinish(_ request: Request) {
        // 请求结束
        
        // 网络指标记录
        if let metrics = request.metrics {
            // 可以在这里添加详细的网络性能指标记录
            // taskInterval在iOS是非可选类型
            let taskInterval = metrics.taskInterval
            print("🔄 请求完成: \(String(format: "%.4f", taskInterval.duration))秒")
            
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
    
    /// 请求解析响应后调用
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        // 请求解析响应
        if let statusCode = response.response?.statusCode {
            print("📊 HTTP状态码: \(statusCode)")
        }
    }
    
    /// 请求创建URL失败时调用
    func request(_ request: Request, didFailToCreateURLRequestWithError error: Error) {
        print("❌ 创建URL请求失败: \(error.localizedDescription)")
    }
    
    /// 任务提前失败时调用
    func request(_ request: Request, didFailTask task: URLSessionTask, earlyWithError error: Error) {
        print("❌ 任务提前失败: \(error.localizedDescription)")
    }
    
    /// 任务完成但有错误时调用
    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: Error?) {
        if let error = error {
            print("❌ 任务完成但有错误: \(error.localizedDescription)")
        }
    }
}
#endif 