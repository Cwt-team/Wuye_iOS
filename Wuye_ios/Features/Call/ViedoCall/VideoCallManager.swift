import Foundation
import Combine
import linphonesw

/// 视频通话业务逻辑管理器
class VideoCallManager: ObservableObject {
    static let shared = VideoCallManager()
    
    @Published var session: VideoCallSession?
    @Published var isLocalVideoEnabled: Bool = true
    @Published var isRemoteVideoEnabled: Bool = true
    @Published var isMuted: Bool = false
    @Published var isCameraFront: Bool = true
    
    private var linphoneCall: linphonesw.Call?
    
    // 新增一个属性来存储待处理的入站呼叫
    var pendingIncomingCall: linphonesw.Call?

    // 新增一个 @Published 属性，表示视频视图是否已准备好
    @Published var areVideoViewsReady: Bool = false

    private var CoreTimer = Timer()

    @Published var isCalling: Bool = false
    @Published var isIncomingCall: Bool = false
    @Published var remoteParty: String?
    @Published var callState: CallState = .idle

    private init() {
        print("[VideoCallManager] 初始化完成。")
        // SipManager 的初始化会在其单例被访问时自动进行
    }
    
    /// 发起视频通话
    func startVideoCall(to remoteUser: String) {
        // 替换为 SipManager.shared 上正确的方法
        linphoneCall = SipManager.shared.startVideoCall(to: remoteUser)
        session = VideoCallSession(
            callId: UUID().uuidString,
            remoteUser: remoteUser,
            startTime: Date(),
            isActive: true,
            isMuted: false,
            isCameraOn: true
        )
    }
    
    /// 接受视频来电 (不再直接调用 Linphone acceptWithParams)
    func acceptVideoCall(call: linphonesw.Call) {
        self.pendingIncomingCall = call // 存储待处理的呼叫
        // 此处不直接调用 Linphone 的 accept，等待视图准备就绪
        print("[VideoCallManager] 收到来电，标记为待处理，等待视频视图准备就绪。")
    }
    
    /// 在视频视图准备就绪后，实际执行 Linphone 的接听操作
    func processPendingIncomingCall() {
        guard let call = pendingIncomingCall, let core = SipManager.shared.getCore() else {
            print("[VideoCallManager] 无待处理来电或Core未初始化，无法处理。")
            return
        }

        print("[VideoCallManager] 视频视图已准备就绪，正在处理待处理来电。")
        self.linphoneCall = call // 将待处理的呼叫设置为当前呼叫
        SipManager.shared.acceptCall() // 调用 SipManager 的实际接听逻辑 (已修改为 acceptCall)

        // 清空待处理呼叫
        self.pendingIncomingCall = nil
        self.areVideoViewsReady = false // 重置状态
    }
    
    /// 挂断通话
    func hangup() {
        print("[VideoCallManager] 正在执行挂断操作。")
        SipManager.shared.terminateCall()
        session = nil
        // 挂断后也清除待处理呼叫，避免残留
        pendingIncomingCall = nil
        areVideoViewsReady = false
    }
    
    /// 切换静音
    func toggleMute() {
        isMuted.toggle()
        if let call = linphoneCall {
            SipManager.shared.toggleMute(isMuted)
        }
    }
    
    /// 切换摄像头
    func switchCamera() {
        isCameraFront.toggle()
        if let core = SipManager.shared.getCore() {
            core.reloadVideoDevices()
            let devices = core.videoDevicesList
            
            guard !devices.isEmpty else {
                print("[VideoCallManager] 没有可用的摄像头设备。")
                return
            }

            let currentDevice = core.videoDevice // This is a String, not Optional
            
            if let currentIndex = devices.firstIndex(of: currentDevice) {
                // Find the next device in the list
                let nextIndex = (currentIndex + 1) % devices.count
                let nextDevice = devices[nextIndex]
                do {
                    try core.setVideodevice(newValue: nextDevice)
                    print("摄像头切换到: \(nextDevice)")
                } catch {
                    print("切换摄像头失败: \(error)")
                }
            } else {
                // 如果当前摄像头未在列表中找到（例如，初始值是空字符串或无效值），
                // 则尝试切换到列表中的第一个摄像头。
                let firstDevice = devices[0]
                do {
                    try core.setVideodevice(newValue: firstDevice)
                    print("当前摄像头 '\(currentDevice)' 未在列表中找到，默认切换到第一个摄像头: \(firstDevice)")
                } catch {
                    print("切换摄像头失败: \(error)")
                }
            }
        }
    }
    
    /// 切换本地视频开关
    func toggleLocalVideo() {
        isLocalVideoEnabled.toggle()
        if let call = linphoneCall {
            SipManager.shared.setLocalVideoEnabled(call: call, enabled: isLocalVideoEnabled)
        }
    }
}
