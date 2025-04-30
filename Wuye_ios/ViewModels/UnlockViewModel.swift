import Foundation
import Combine

// MARK: - 开锁视图模型
class UnlockViewModel: ObservableObject {
    // 发布属性
    @Published var isUnlocking = false
    @Published var unlockResult: String?
    @Published var errorMessage: String?
    @Published var doorCode: String = ""
    @Published var recentUnlockRecords: [UnlockRecordViewModel] = []
    
    // 私有属性
    private let doorService = DoorService.shared
    private let authManager = AuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 初始化方法
    init() {
        loadRecentUnlockRecords()
    }
    
    // MARK: - 公共方法
    
    /// 通过手动输入的门禁编码开锁
    func unlockWithCode() {
        guard !doorCode.isEmpty else {
            errorMessage = "请输入门锁编号"
            return
        }
        
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "用户未登录"
            return
        }
        
        isUnlocking = true
        errorMessage = nil
        unlockResult = nil
        
        doorService.unlockDoorByCode(code: doorCode, userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isUnlocking = false
                    
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] success in
                    self?.isUnlocking = false
                    self?.unlockResult = success ? "开锁成功" : "开锁失败，请重试"
                    
                    // 重新加载记录
                    self?.loadRecentUnlockRecords()
                }
            )
            .store(in: &cancellables)
    }
    
    /// 通过扫描二维码开锁
    /// - Parameter qrData: 二维码数据
    func unlockWithQRCode(qrData: String) {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "用户未登录"
            return
        }
        
        isUnlocking = true
        errorMessage = nil
        unlockResult = nil
        
        doorService.scanQRCode(qrData: qrData, userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isUnlocking = false
                    
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] success in
                    self?.isUnlocking = false
                    self?.unlockResult = success ? "开锁成功" : "开锁失败，请重试"
                    
                    // 重新加载记录
                    self?.loadRecentUnlockRecords()
                }
            )
            .store(in: &cancellables)
    }
    
    /// 清除结果和错误消息
    func clearMessages() {
        errorMessage = nil
        unlockResult = nil
    }
    
    // MARK: - 私有方法
    
    /// 加载最近的开锁记录
    private func loadRecentUnlockRecords() {
        guard let userId = authManager.currentUser?.id else {
            return
        }
        
        doorService.getUnlockRecords(userId: userId, limit: 5)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] records in
                    self?.recentUnlockRecords = records.map { UnlockRecordViewModel(record: $0) }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 开锁记录视图模型
struct UnlockRecordViewModel: Identifiable {
    let id: String
    let doorId: Int64
    let doorName: String
    let dateTime: String
    let status: String
    let isSuccess: Bool
    
    init(record: UnlockRecord) {
        self.id = "\(record.id ?? 0)"
        self.doorId = record.doorId
        self.doorName = "门禁 #\(record.doorId)" // 实际应用中应该获取门禁名称
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        self.dateTime = dateFormatter.string(from: record.unlockTime)
        
        self.status = record.isSuccess ? "成功" : "失败"
        self.isSuccess = record.isSuccess
    }
} 