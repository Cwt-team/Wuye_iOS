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
    
    private init() {}
    
    /// 发起视频通话
    func startVideoCall(to remoteUser: String) {
        // 这里假设 SipManager 已经有发起视频通话的接口
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
    
    /// 接听视频来电
    func acceptVideoCall(call: linphonesw.Call) {
        linphoneCall = call
        SipManager.shared.acceptVideoCall(call: call)
        session = VideoCallSession(
            callId: UUID().uuidString,
            remoteUser: call.remoteAddress?.asString() ?? "未知",
            startTime: Date(),
            isActive: true,
            isMuted: false,
            isCameraOn: true
        )
    }
    
    /// 挂断通话
    func hangup() {
        if let call = linphoneCall {
            SipManager.shared.terminateCall()
        }
        session = nil
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
        // SipManager.shared.switchCamera(isFront: isCameraFront)
    }
    
    /// 切换本地视频开关
    func toggleLocalVideo() {
        isLocalVideoEnabled.toggle()
        if let call = linphoneCall {
            SipManager.shared.setLocalVideoEnabled(call: call, enabled: isLocalVideoEnabled)
        }
    }
}
