import SwiftUI
import AVFoundation
import linphonesw
import AudioToolbox
import UserNotifications

// 呼叫管理器类 - 处理来电和通话状态
class CallManager: ObservableObject {
    // 添加单例实例
    static let shared = CallManager()
    
    // 发布状态变化
    @Published var state: CallManagerState = .idle
    @Published var currentCaller: String = ""
    @Published var currentNumber: String = ""
    @Published var errorMessage: String = ""
    
    // 私有初始化器确保只有一个实例
    private init() {
        print("[CallManager] 开始初始化")
        self.sipManager = SipManager.shared
        setupAudioPermissions()
        self.setupCallbacks()
        
        // 立即设置回调，而不是延迟
        self.setupCallbacks()
        
        // 添加模拟器特有的模拟来电通知监听
        #if targetEnvironment(simulator)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSimulatedIncomingCall(_:)),
            name: NSNotification.Name("SimulatedIncomingCall"),
            object: nil
        )
        print("[CallManager] 模拟器环境：已添加模拟来电通知监听")
        #endif
        
        // 延迟刷新SIP注册
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshSipRegistration()
            print("[CallManager] 已初始化并刷新SIP注册")
        }
    }
    
    @Published var incomingCall: IncomingCallInfo?
    @Published var isCallActive: Bool = false
    @Published var callStartTime: Date? = nil
    
    // 使用weak避免循环引用
    private weak var sipManager: SipManager?
    // 修改为强引用以确保callback不会被释放
    private var callbackHandler: IncomingCallHandler?
    
    // 设置回调
    private func setupCallbacks() {
        SipManager.shared.setCallback(CallManagerCallback(manager: self))
    }
    
    private func setupAudioPermissions() {
        // 请求麦克风权限
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                print("[CallManager] 麦克风权限已获取")
            } else {
                print("[CallManager] 麦克风权限被拒绝")
            }
        }
    }
    
    // 处理来电
    func handleIncomingCall(caller: String, number: String) {
        guard self.state != .incoming, self.incomingCall == nil else { return }
        DispatchQueue.main.async {
            self.state = .incoming
            self.currentCaller = caller
            self.currentNumber = number
            self.incomingCall = IncomingCallInfo(name: caller, number: number)
            RingtonePlayer.shared.play()
        }
    }
    
    // 清理来电状态
    func clearIncomingCall() {
        DispatchQueue.main.async {
            self.incomingCall = nil
            self.state = .idle
            self.currentCaller = ""
            self.currentNumber = ""
            self.errorMessage = ""
            RingtonePlayer.shared.stop()
            NotificationCenter.default.post(name: NSNotification.Name("IncomingCallEnded"), object: nil)
        }
    }
    
    // 播放来电提示音
    private func playIncomingCallSound() {
        AudioServicesPlaySystemSound(1016) // 系统铃声ID
    }
    
    // 结束通话
    func endCall() {
        print("[CallManager] 结束通话")
        sipManager?.terminateCall()
        clearIncomingCall() // 这里会自动停止振铃和关闭UI
    }
    
    // 切换静音状态
    func toggleMute() {
        print("[CallManager] 切换静音状态")
        if let manager = sipManager {
            // 使用SipManager中已实现的toggleMute方法
            let isMuted = manager.isMuted
            manager.toggleMute(!isMuted)
            print("[CallManager] 麦克风状态已切换为: \(manager.isMuted ? "静音" : "非静音")")
        } else {
            print("[CallManager] 错误：SIP管理器未初始化")
        }
    }
    
    // 切换扬声器状态
    func toggleSpeaker() {
        print("[CallManager] 切换扬声器状态")
        let currentMode = AVAudioSession.sharedInstance().mode
        let isSpeakerActive = currentMode == AVAudioSession.Mode.videoChat
        
        do {
            if isSpeakerActive {
                // 切换到听筒模式
                try AVAudioSession.sharedInstance().setMode(.voiceChat)
            } else {
                // 切换到扬声器模式
                try AVAudioSession.sharedInstance().setMode(.videoChat)
            }
        } catch {
            print("[CallManager] 切换音频模式失败: \(error)")
        }
    }
    
    // 刷新SIP注册
    func refreshSipRegistration() {
        print("[CallManager] 刷新SIP注册")
        sipManager?.refreshRegistrations()
    }
    
    // 添加模拟器特有的处理方法
    #if targetEnvironment(simulator)
    @objc private func handleSimulatedIncomingCall(_ notification: NSNotification) {
        print("[CallManager] 收到模拟来电通知")
        
        guard let userInfo = notification.userInfo else {
            print("[CallManager] 通知中没有用户信息")
            return
        }
        
        guard let caller = userInfo["caller"] as? String,
              let number = userInfo["number"] as? String else {
            print("[CallManager] 通知中缺少来电者信息")
            return
        }
        
        // 直接调用处理来电的方法
        self.handleIncomingCall(caller: caller, number: number)
    }
    #endif
    
    // 其他必要的方法
    func onCallFailed(reason: String) {
        print("[CallManager] 通话失败: \(reason)")
        DispatchQueue.main.async {
            self.state = .failed
            self.errorMessage = reason
        }
    }
    
    func onCallEstablished() {
        print("[CallManager] 通话已建立")
        DispatchQueue.main.async {
            self.state = .connected
        }
    }
    
    func onCallEnded() {
        print("[CallManager] 通话已结束")
        DispatchQueue.main.async {
            self.state = .ended
        }
    }
    
    // 清理当前通话状态
    func clearCurrentCall() {
        DispatchQueue.main.async {
            self.state = .idle
            self.currentCaller = ""
            self.currentNumber = ""
            self.errorMessage = ""
        }
    }
}

// 来电信息模型
struct IncomingCallInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let number: String
    
    // 为了符合Equatable协议，需要实现相等比较方法
    static func == (lhs: IncomingCallInfo, rhs: IncomingCallInfo) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.number == rhs.number
    }
}

// SIP回调处理类
class IncomingCallHandler: SipManagerCallback {
    private weak var callManager: CallManager?
    
    init(callManager: CallManager) {
        self.callManager = callManager
    }
    
    // 增强onIncomingCall方法的日志输出
    func onIncomingCall(call: linphonesw.Call, caller: String) {
        print("[SIP-详细] 收到新来电: 呼叫者=\(caller), 号码=\(call.remoteAddressAsString)")
        print("[SIP-详细] 呼叫对象状态: \(call.state.rawValue), 持续时间: \(call.duration)秒")
        
        DispatchQueue.main.async {
            // 播放系统声音提示新来电
            AudioServicesPlaySystemSound(1016) // 系统铃声ID
            
            // 更新UI显示来电信息
            self.callManager?.handleIncomingCall(caller: caller, number: call.remoteAddressAsString)
            
            print("[SIP-详细] UI更新已触发，呼叫管理器状态: \(self.callManager?.isCallActive ?? false)")
        }
    }
    
    func onRegistrationStateChanged(state: RegState, message: String) {
        // 仅用于日志记录
        print("[IncomingCallHandler] 注册状态变更: \(state) - \(message)")
    }
    
    func onCallStateChanged(state: linphonesw.Call.State, message: String) {
        print("[IncomingCallHandler] 呼叫状态变更: \(state) - \(message)")
        
        // 如果通话结束，清除来电状态
        if state == .End || state == .Error || state == .Released {
            DispatchQueue.main.async {
                self.callManager?.clearIncomingCall()
            }
        }
    }
    
    func onCallEstablished() {
        print("[IncomingCallHandler] 通话已建立")
    }
    
    func onCallEnded() {
        print("[IncomingCallHandler] 通话已结束")
        DispatchQueue.main.async {
            self.callManager?.clearIncomingCall()
        }
    }
    
    func onRegistrationSuccess() {
        print("[IncomingCallHandler] 注册成功")
    }
    
    func onRegistrationFailed(reason: String) {
        print("[IncomingCallHandler] 注册失败: \(reason)")
    }
    
    func onCallFailed(reason: String) {
        print("[IncomingCallHandler] 通话失败: \(reason)")
        DispatchQueue.main.async {
            self.callManager?.clearIncomingCall()
        }
    }
    
    // 实现协议中的其他必要方法
    func onSipRegistrationStateChanged(isSuccess: Bool, message: String) {
        print("[IncomingCallHandler] SIP注册状态: \(isSuccess ? "成功" : "失败") - \(message)")
    }
    
    func onCallQualityChanged(quality: Float, message: String) {
        print("[IncomingCallHandler] 通话质量变更: \(quality) - \(message)")
    }
}

// CallManager 的回调处理类
class CallManagerCallback: SipManagerCallback {
    weak var manager: CallManager?
    
    init(manager: CallManager) {
        self.manager = manager
    }
    
    func onRegistrationSuccess() {}
    func onRegistrationFailed(reason: String) {}
    
    func onIncomingCall(call: linphonesw.Call, caller: String) {
        DispatchQueue.main.async {
            let number = call.remoteAddress?.username ?? caller
            self.manager?.handleIncomingCall(caller: caller, number: number)
        }
    }
    
    func onCallFailed(reason: String) {
        DispatchQueue.main.async {
            self.manager?.onCallFailed(reason: reason)
        }
    }
    
    func onCallEstablished() {
        DispatchQueue.main.async {
            self.manager?.onCallEstablished()
        }
    }
    
    func onCallEnded() {
        DispatchQueue.main.async {
            self.manager?.onCallEnded()
        }
    }
    
    func onSipRegistrationStateChanged(isSuccess: Bool, message: String) {}
    func onCallQualityChanged(quality: Float, message: String) {}
}

// 添加通话状态枚举
enum CallManagerState {
    case idle, incoming, connecting, connected, ended, failed
}

class RingtonePlayer {
    static let shared = RingtonePlayer()
    private var isPlaying = false

    func play() {
        stop()
        isPlaying = true
        AudioServicesPlaySystemSound(1016) // 系统来电铃声
    }

    func stop() {
        isPlaying = false
        // 系统声音无需手动stop
    }
}
