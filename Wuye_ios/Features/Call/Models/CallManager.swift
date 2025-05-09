import SwiftUI
import AVFoundation
import linphonesw
import AudioToolbox
import UserNotifications

// 呼叫管理器类 - 处理来电和通话状态
class CallManager: ObservableObject {
    @Published var incomingCall: IncomingCallInfo?
    @Published var isCallActive: Bool = false
    @Published var callStartTime: Date? = nil
    
    // 使用weak避免循环引用
    private weak var sipManager: SipManager?
    // 修改为强引用以确保callback不会被释放
    private var callbackHandler: IncomingCallHandler?
    
    init() {
        print("[CallManager] 开始初始化")
        // 先获取SipManager引用，避免重复创建
        self.sipManager = SipManager.shared
        setupAudioPermissions()
        
        // 立即设置回调，而不是延迟
        self.setupCallbackHandler()
        
        // 延迟刷新SIP注册
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshSipRegistration()
            print("[CallManager] 已初始化并刷新SIP注册")
        }
    }
    
    private func setupCallbackHandler() {
        // 创建回调处理程序
        self.callbackHandler = IncomingCallHandler(callManager: self)
        if let callback = self.callbackHandler {
            sipManager?.setSipCallback(callback)
        print("[CallManager] 已设置SIP回调处理程序")
        } else {
            print("[CallManager] 警告：无法创建回调处理程序")
        }
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
        // 确保在主线程更新UI
        if !Thread.isMainThread {
        DispatchQueue.main.async {
                self.handleIncomingCall(caller: caller, number: number)
            }
            return
        }
        
        // 生成一个唯一来电ID以便跟踪
        let callId = UUID().uuidString.prefix(8)
        print("[CallManager] 收到来电 [\(callId)]: \(caller) - \(number)")
        
        // 设置来电信息
            self.incomingCall = IncomingCallInfo(name: caller, number: number)
        self.isCallActive = true
        
        // 播放系统声音提示来电
            self.playIncomingCallSound()
        
        // 详细记录来电状态
        print("[CallManager] [\(callId)] 来电信息已设置: name=\(caller), number=\(number)")
        print("[CallManager] [\(callId)] 活动状态已更新: isCallActive=\(self.isCallActive)")
        print("[CallManager] [\(callId)] incomingCall对象: \(String(describing: self.incomingCall))")
        
        // 立即发送通知以触发UI更新
        print("[CallManager] [\(callId)] 正在发送来电通知...")
        let callInfo: [String: Any] = [
            "caller": caller,
            "number": number,
            "id": callId
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("IncomingCallReceived"),
            object: self,
            userInfo: callInfo
        )
        print("[CallManager] [\(callId)] 来电通知已发送")
        
        // 延迟500毫秒后再次发送通知，确保UI接收到
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("[CallManager] [\(callId)] 发送延迟备份通知...")
            NotificationCenter.default.post(
                name: NSNotification.Name("IncomingCallReceived"),
                object: self,
                userInfo: callInfo
            )
        }
        
        // 发送系统通知以在后台提醒用户
        let content = UNMutableNotificationContent()
        content.title = "来电"
        content.body = "\(caller) 正在呼叫你"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: "call-\(callId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[CallManager] [\(callId)] 发送系统通知失败: \(error)")
            } else {
                print("[CallManager] [\(callId)] 系统通知已发送")
            }
        }
    }
    
    // 清除来电状态
    func clearIncomingCall() {
        DispatchQueue.main.async {
            print("[CallManager] 清除来电状态")
            self.incomingCall = nil
            self.isCallActive = false
            
            // 发送通知，以便LaunchView关闭来电界面
            print("[CallManager] 正在发送来电结束通知...")
            NotificationCenter.default.post(name: NSNotification.Name("IncomingCallEnded"), object: nil)
            print("[CallManager] 已发送来电结束通知")
        }
    }
    
    // 播放来电提示音
    private func playIncomingCallSound() {
        AudioServicesPlaySystemSound(1016) // 系统铃声ID
    }
    
    // 发起呼叫
    func makeCall(to number: String, name: String = "直接拨号") {
        print("[CallManager] 拨打电话: \(number)")
        // SIP呼叫
        sipManager?.call(recipient: number)
        isCallActive = true
        callStartTime = Date()
    }
    
    // 结束通话
    func endCall() {
        print("[CallManager] 结束通话")
        sipManager?.terminateCall()
        clearIncomingCall()
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