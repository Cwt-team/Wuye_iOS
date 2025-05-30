import SwiftUI
import AVFoundation
import linphonesw

struct CallView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var sipManager = SipManager.shared
    
    let callerName: String
    let callerNumber: String
    let isIncoming: Bool
    
    @State private var callStatus: String = "正在连接..."
    @State private var callDuration: Int = 0
    @State private var callTimer: Timer?
    @State private var isConnected: Bool = false
    
    // UI状态
    @State private var isHangupConfirmationPresented = false
    
    // 添加状态变量
    @State private var shouldDismiss = false
    
    init(callerName: String, callerNumber: String, isIncoming: Bool = false) {
        self.callerName = callerName
        self.callerNumber = callerNumber
        self.isIncoming = isIncoming
        
        // 创建并设置回调，但不捕获self
        setupCallbackOnInit()
    }
    
    // 在初始化时静态设置回调
    private func setupCallbackOnInit() {
        let handler = CallViewCallback(
            onCallFailed: {
                // 不能在这里访问self
                // 我们将在回调中使用通知中心或其他方式通知视图
                NotificationCenter.default.post(name: NSNotification.Name("CallFailedNotification"), object: nil)
            },
            onCallEnded: {
                NotificationCenter.default.post(name: NSNotification.Name("CallEndedNotification"), object: nil)
            }
        )
        
        SipManager.shared.setCallback(handler)
    }
    
    var body: some View {
        ZStack {
            // 背景
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Spacer()
                
                // 用户信息
                VStack(spacing: 10) {
                    Text(callerName)
                        .font(.system(size: 28, weight: .semibold))
                    
                    if !isConnected && isIncoming {
                        Text("来电")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(callerNumber)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if isConnected {
                        Text(formatDuration(callDuration))
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    } else {
                        Text(callStatus)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, 40)
                
                Spacer()
                
                // 通话控制按钮
                if isIncoming && !isConnected {
                    // 来电接听/拒绝按钮
                    HStack(spacing: 60) {
                        // 拒绝按钮
                        CallButton(
                            icon: "phone.down.fill",
                            background: .red,
                            action: {
                                hangupCall()
                            }
                        )
                        
                        // 接听按钮
                        CallButton(
                            icon: "phone.fill",
                            background: .green,
                            action: {
                                answerCall()
                            }
                        )
                    }
                } else {
                    // 通话中控制按钮
                    VStack(spacing: 30) {
                        // 第一行按钮
                        HStack(spacing: 60) {
                            // 静音按钮
                            ControlButton(
                                icon: sipManager.isMuted ? "mic.slash.fill" : "mic.fill",
                                label: "静音",
                                isActive: sipManager.isMuted,
                                action: {
                                    sipManager.toggleMute(!sipManager.isMuted)
                                }
                            )
                            
                            // 扬声器按钮
                            ControlButton(
                                icon: "speaker.wave.2.fill",
                                label: "扬声器",
                                isActive: sipManager.isSpeakerEnabled,
                                action: {
                                    sipManager.toggleSpeaker(!sipManager.isSpeakerEnabled)
                                }
                            )
                        }
                        
                        // 挂断按钮
                        CallButton(
                            icon: "phone.down.fill",
                            background: .red,
                            action: {
                                hangupCall()
                            }
                        )
                        .padding(.top, 20)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            setupCallHandling()
            
            // 添加通知观察者
            NotificationCenter.default.addObserver(forName: NSNotification.Name("CallFailedNotification"), object: nil, queue: .main) { _ in
                self.shouldDismiss = true
            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name("CallEndedNotification"), object: nil, queue: .main) { _ in
                self.shouldDismiss = true
            }
        }
        .onDisappear {
            // 移除通知观察者
            NotificationCenter.default.removeObserver(self)
            
            callTimer?.invalidate()
            callTimer = nil
            if let currentCall = sipManager.currentCall {
                sipManager.terminateCall()
            }
        }
        .onChange(of: sipManager.callState) { newState in
            updateCallStatus()
        }
        .onChange(of: shouldDismiss) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .alert(isPresented: $isHangupConfirmationPresented) {
            Alert(
                title: Text("确认挂断"),
                message: Text("您确定要结束当前通话吗？"),
                primaryButton: .destructive(Text("挂断")) {
                    sipManager.terminateCall()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    // MARK: - 辅助方法
    
    private func setupCallHandling() {
        // 立即更新状态
        updateCallStatus()
        
        // 如果已连接，开始计时
        if sipManager.callState == .connected || sipManager.callState == .running {
            isConnected = true
            startCallTimer()
        }
    }
    
    private func answerCall() {
        callStatus = "正在接听..."
        sipManager.acceptCall()
    }
    
    private func hangupCall() {
        if isConnected {
            isHangupConfirmationPresented = true
        } else {
            callStatus = "正在挂断..."
            sipManager.terminateCall()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func updateCallStatus() {
        switch sipManager.callState {
        case .outgoingInit, .ringing:
            callStatus = "正在呼叫..."
        case .incoming:
            print("[UI日志] CallView 收到来电状态，准备显示来电界面")
            callStatus = "来电..."
        case .connected, .running:
            isConnected = true
            callStatus = "已接通"
            startCallTimer()
        case .paused:
            callStatus = "通话已暂停"
        case .ended:
            callStatus = "通话已结束"
            callTimer?.invalidate()
        case .released, .error:
            callStatus = "通话已结束"
            callTimer?.invalidate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                presentationMode.wrappedValue.dismiss()
            }
        default:
            callStatus = "通话中..."
        }
    }
    
    private func startCallTimer() {
        // 先停止任何现有计时器
        callTimer?.invalidate()
        
        // 开始新计时器
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.callDuration += 1
        }
        
        // 确保计时器在UI滚动时继续运行
        RunLoop.current.add(callTimer!, forMode: .common)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    // 更新状态方法，供回调使用
    fileprivate func updateConnectionState(_ isConnected: Bool) {
        self.isConnected = isConnected
        if isConnected {
            callStatus = "已接通"
            startCallTimer()
        }
    }
    
    // 设置错误状态
    fileprivate func setErrorState(_ reason: String) {
        callStatus = "错误: \(reason)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // 添加结束通话方法
    private func endCall() {
        sipManager.terminateCall()
        shouldDismiss = true
    }
}

// MARK: - 辅助视图

// 通话主按钮
struct CallButton: View {
    let icon: String
    let background: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(background)
                    .frame(width: 64, height: 64)
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
        }
    }
}

// 控制按钮
struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isActive ? .blue : .gray)
                }
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(isActive ? .blue : .gray)
            }
        }
    }
}

// MARK: - 预览
struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 来电预览
            CallView(callerName: "张三", callerNumber: "13800138000", isIncoming: true)
                .previewDisplayName("来电")
            
            // 拨出电话预览
            CallView(callerName: "李四", callerNumber: "13900139000", isIncoming: false)
                .previewDisplayName("拨出")
        }
    }
}

// SIP回调处理器
class CallViewCallback: SipManagerCallback {
    private let onCallFailedAction: () -> Void
    private let onCallEndedAction: () -> Void
    
    init(onCallFailed: @escaping () -> Void, onCallEnded: @escaping () -> Void) {
        self.onCallFailedAction = onCallFailed
        self.onCallEndedAction = onCallEnded
    }
    
    // 实现所有回调方法
    func onRegistrationSuccess() {}
    func onRegistrationFailed(reason: String) {}
    func onIncomingCall(call: linphonesw.Call, caller: String) {}
    
    func onCallFailed(reason: String) {
        self.onCallFailedAction()
    }
    
    func onCallEstablished() {}
    
    func onCallEnded() {
        self.onCallEndedAction()
    }
    
    func onSipRegistrationStateChanged(isSuccess: Bool, message: String) {}
    func onCallQualityChanged(quality: Float, message: String) {}
}
