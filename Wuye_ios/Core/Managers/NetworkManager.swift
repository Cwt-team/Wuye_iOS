//
//  NetworkManager.swift
//  Wuye_ios
//
//  Created by CUI King on 2025/4/28.
//

import Foundation
import Network
import Combine

/// 网络连接状态
enum NetworkStatus {
    case connected
    case disconnected
}

/// 网络连接类型
enum ConnectionType {
    case wifi
    case cellular
    case other
    case none
}

/// 网络管理器类
class NetworkManager: ObservableObject {
    // 单例
    static let shared = NetworkManager()
    
    // 发布属性
    @Published var status: NetworkStatus = .disconnected
    @Published var connectionType: ConnectionType = .none
    
    // 网络路径监视器
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // 私有属性
    private var isPerformingSync = false
    private var syncTimer: Timer?
    private var repositories: [RepositoryProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    
    // 私有初始化方法
    private init() {
        setupNetworkMonitoring()
        registerRepositories()
    }
    
    // MARK: - 公共方法
    
    /// 添加仓库到同步列表
    /// - Parameter repository: 实现了RepositoryProtocol的仓库
    func addRepositoryForSync(_ repository: RepositoryProtocol) {
        if !repositories.contains(where: { $0 === repository }) {
            repositories.append(repository)
        }
    }
    
    /// 手动触发数据同步
    /// - Parameter completion: 同步完成回调
    func syncData(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard status == .connected, !isPerformingSync else {
            if status != .connected {
                completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "网络未连接"])))
            } else {
                completion(.failure(NSError(domain: "NetworkManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "同步正在进行中"])))
            }
            return
        }
        
        isPerformingSync = true
        
        let group = DispatchGroup()
        var syncErrors: [Error] = []
        
        // 同步所有仓库
        for repository in repositories {
            group.enter()
            
            repository.syncPendingChanges()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            syncErrors.append(error)
                        }
                        group.leave()
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isPerformingSync = false
            
            if syncErrors.isEmpty {
                completion(.success(true))
            } else {
                let error = NSError(
                    domain: "NetworkManager",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "同步过程中出现错误",
                        "errors": syncErrors
                    ]
                )
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 设置网络监控
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                // 更新网络连接状态
                if path.status == .satisfied {
                    self?.status = .connected
                    
                    // 确定连接类型
                    if path.usesInterfaceType(.wifi) {
                        self?.connectionType = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        self?.connectionType = .cellular
                    } else {
                        self?.connectionType = .other
                    }
                    
                    // 网络恢复时尝试同步数据
                    self?.attemptSyncWhenConnected()
                } else {
                    self?.status = .disconnected
                    self?.connectionType = .none
                    
                    // 网络断开时停止同步定时器
                    self?.stopSyncTimer()
                }
                
                print("网络状态变更: \(self?.status == .connected ? "已连接" : "已断开"), 类型: \(self?.connectionType.description ?? "无")")
            }
        }
        
        // 开始监控
        monitor.start(queue: queue)
    }
    
    /// 在网络连接恢复时尝试同步数据
    private func attemptSyncWhenConnected() {
        // 如果已经在同步，则不重复执行
        guard !isPerformingSync else { return }
        
        // 立即尝试同步一次
        syncData { _ in
            // 忽略结果，只是尝试同步
        }
        
        // 启动定时同步
        startSyncTimer()
    }
    
    /// 启动同步定时器
    private func startSyncTimer() {
        // 确保先停止之前的定时器
        stopSyncTimer()
        
        // 每5分钟尝试同步一次
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.syncData { _ in
                // 忽略结果，定时同步
            }
        }
    }
    
    /// 停止同步定时器
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// 注册需要同步的数据仓库
    private func registerRepositories() {
        // 注册用户仓库
        addRepositoryForSync(RepositoryFactory.shared.getUserRepository())
        
        // 注册物业仓库
        addRepositoryForSync(RepositoryFactory.shared.getPropertyRepository())
        
        // 在此处添加更多仓库
    }
}

// MARK: - ConnectionType描述扩展
extension ConnectionType {
    var description: String {
        switch self {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "蜂窝数据"
        case .other:
            return "其他"
        case .none:
            return "无连接"
        }
    }
}

