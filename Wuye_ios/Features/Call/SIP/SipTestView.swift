import SwiftUI
import Combine
import linphonesw
import AVFoundation

struct SipTestView: View {
    @State private var server: String = UserDefaults.standard.string(forKey: "sipDomain") ?? ""
    @State private var port: String = UserDefaults.standard.string(forKey: "sipPort") ?? "5060"
    @State private var username: String = UserDefaults.standard.string(forKey: "sipUsername") ?? "5001"
    @State private var password: String = UserDefaults.standard.string(forKey: "sipPassword") ?? "5001"
    @State private var callTarget: String = UserDefaults.standard.string(forKey: "sipTarget") ?? "5000"
    @State private var transportType: String = UserDefaults.standard.string(forKey: "sipTransport") ?? "UDP"
    
    @State var status: String = "未注册"
    @State var callStatus: String = "空闲"
    @State var isRegistering: Bool = false
    @State var isCalling: Bool = false
    @State var isRegistered: Bool = false
    @State private var isMuted: Bool = false
    @State private var isSpeakerOn: Bool = false
    @State private var logMessages: [String] = []
    @State private var showAdvancedSettings: Bool = false
    @State private var showConnectionInfo: Bool = false
    @State private var showLogs: Bool = false
    
    // 新增注册超时计时器
    @State private var registrationTimer: Timer? = nil
    
    // 新增的连接信息
    @State private var networkType: String = "未知"
    @State private var localIP: String = "未知"
    @State private var signalStrength: Int = 0
    @State var audioQuality: String = "未知"
    @State private var callLatency: String = "未知"
    
    @ObservedObject private var sipManager = SipManager.shared
    private let callManager = CallManager.shared
    
    // 取消订阅存储
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("SIP服务器配置")) {
                    TextField("SIP服务器", text: $server)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                    
                    TextField("用户名", text: $username)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.none)
                    
                    SecureField("密码", text: $password)
                    
                    Picker("传输方式", selection: $transportType) {
                        Text("UDP").tag("UDP")
                        Text("TCP").tag("TCP")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("注册状态")) {
                    HStack {
                        Text("状态:")
                        Spacer()
                        Text(status)
                            .foregroundColor(getStatusColor())
                    }
                    
                    Button(action: {
                        startRegistration()
                    }) {
                        Text(isRegistering ? "注册中..." : "测试注册")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding()
                            .background(isRegistering ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(isRegistering)
                    
                    if isRegistered {
                        Button(action: {
                            unregister()
                        }) {
                            HStack {
                                Text("注销")
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                
                if isRegistered {
                    // 新增通话信息区域
                    if isCalling && showConnectionInfo {
                        Section(header: Text("通话信息")) {
                            HStack {
                                Text("网络类型:")
                                Spacer()
                                Text(networkType)
                            }
                            
                            HStack {
                                Text("本地IP:")
                                Spacer()
                                Text(localIP)
                            }
                            
                            HStack {
                                Text("信号强度:")
                                Spacer()
                                signalStrengthView
                            }
                            
                            HStack {
                                Text("音频质量:")
                                Spacer()
                                Text(audioQuality)
                            }
                            
                            HStack {
                                Text("通话延迟:")
                                Spacer()
                                Text(callLatency)
                            }
                            
                            HStack {
                                Text("Linphone版本:")
                                Spacer()
                                Text(sipManager.getVersionInfo())
                            }
                        }
                    }
                }
                
                // 新增的高级设置区域
                DisclosureGroup("高级设置", isExpanded: $showAdvancedSettings) {
                    Toggle("显示通话信息", isOn: $showConnectionInfo)
                    
                    Toggle("显示日志", isOn: $showLogs)
                    
                    Button("诊断音频设备") {
                        diagnoseAudioDevices()
                    }
                    
                    Button("重置SIP设置") {
                        resetSipSettings()
                    }
                    .foregroundColor(.red)
                }
                
                // 日志区域
                if showLogs {
                    Section(header: Text("SIP日志")) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(logMessages, id: \.self) { message in
                                    Text(message)
                                        .font(.system(size: 12))
                                        .lineLimit(nil)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                        .frame(height: 200)
                    }
                }
            }
            .navigationBarTitle("SIP测试", displayMode: .inline)
            .onAppear {
                // 设置对SipManager状态的订阅
                setupObservers()
                
                // 清空日志
                logMessages.removeAll()
                addLog("SIP日志: 视图已加载，当前注册状态: \(sipManager.registrationState)")
                
                // 添加来电通知观察者
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("IncomingCallNotification"),
                    object: nil,
                    queue: .main) { notification in
                        if let userInfo = notification.userInfo,
                           let caller = userInfo["caller"] as? String {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("UpdateCallStatusNotification"),
                                                               object: "来电: \(caller)")
                            }
                        }
                    }
                
                // 然后添加另一个观察者来处理状态更新
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("UpdateCallStatusNotification"),
                    object: nil,
                    queue: .main) { notification in
                        if let statusText = notification.object as? String {
                            self.updateCallStatus(statusText)
                        }
                    }
                
                // 更新状态
                updateStatus()
            }
            .onDisappear {
                // 清理计时器
                registrationTimer?.invalidate()
                registrationTimer = nil
                
                // 清理订阅
                cancellables.forEach { $0.cancel() }
                cancellables.removeAll()
                
                // 移除通知观察者
                NotificationCenter.default.removeObserver(self)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // 信号强度显示视图
    private var signalStrengthView: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .frame(width: 6, height: 6 + CGFloat(index) * 3)
                    .foregroundColor(index < signalStrength ? .green : .gray.opacity(0.3))
            }
        }
    }
    
    // 设置观察者
    private func setupObservers() {
        // 观察注册状态变化
        sipManager.$registrationState
            .receive(on: DispatchQueue.main)
            .sink { newState in
                self.addLog("SIP日志: 注册状态变化为: \(newState)")
                self.updateStatus()
                
                // 如果注册成功或失败，停止计时器
                if newState == .ok || newState == .failed || newState == .cleared {
                    self.registrationTimer?.invalidate()
                    self.registrationTimer = nil
                    self.isRegistering = false
                }
            }
            .store(in: &cancellables)
        
        // 观察通话状态变化
        sipManager.$callState
            .receive(on: DispatchQueue.main)
            .sink { newState in
                self.addLog("SIP日志: 通话状态变化为: \(newState)")
                self.updateStatus()
            }
            .store(in: &cancellables)
    }
    
    private func addLog(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            logMessages.append("[\(timestamp)] \(message)")
            // 限制日志数量
            if logMessages.count > 100 {
                logMessages.removeFirst(logMessages.count - 100)
            }
        }
    }
    
    private func getStatusColor() -> Color {
        switch sipManager.registrationState {
        case .ok:
            return .green
        case .progress:
            return .orange
        case .failed:
            return .red
        default:
            return .gray
        }
    }
    
    private func getCallStatusColor() -> Color {
        switch sipManager.callState {
        case .running, .connected:
            return .green
        case .ringing, .outgoingInit:
            return .orange
        case .error, .ended:
            return .red
        default:
            return .gray
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(server, forKey: "sipDomain")
        UserDefaults.standard.set(port, forKey: "sipPort")
        UserDefaults.standard.set(username, forKey: "sipUsername")
        UserDefaults.standard.set(password, forKey: "sipPassword")
        UserDefaults.standard.set(callTarget, forKey: "sipTarget")
        UserDefaults.standard.set(transportType, forKey: "sipTransport")
    }
    
    private func startRegistration() {
        isRegistering = true
        status = "注册中..."
        
        // 保存SIP账户信息
        saveSettings()
        
        // 重新设置回调
        setSipCallback()
        
        // 启动SIP连接
        addLog("SIP日志: 开始SIP注册 - 域名: \(server), 端口: \(port), 用户名: \(username), 传输: \(transportType)")
        
        // 运行在主线程上以确保UI正确更新
        DispatchQueue.main.async {
            // 配置SIP账户
            SipManager.shared.configureSipAccount(
                username: username,
                password: password,
                domain: server,
                port: port,
                transport: transportType
            )
        }
        
        // 设置注册超时
        registrationTimer?.invalidate()
        registrationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            if self.sipManager.registrationState == .progress {
                self.isRegistering = false
                self.status = "注册超时"
                self.addLog("SIP日志: 注册超时")
                
                // 尝试取消注册
                self.unregister()
            }
        }
    }
    
    private func updateStatus() {
        switch sipManager.registrationState {
        case .ok:
            status = "已注册"
            isRegistered = true
            isRegistering = false
        case .progress:
            status = "注册中..."
            isRegistered = false
        case .failed:
            status = "注册失败"
            isRegistered = false
            isRegistering = false
        case .cleared:
            status = "已注销"
            isRegistered = false
            isRegistering = false
        default:
            status = "未注册"
            isRegistered = false
            isRegistering = false
        }
        
        switch sipManager.callState {
        case .idle:
            callStatus = "空闲"
            isCalling = false
        case .outgoingInit:
            callStatus = "呼叫中..."
            isCalling = true
        case .ringing:
            callStatus = "响铃中..."
            isCalling = true
        case .connected:
            callStatus = "已接通"
            isCalling = true
        case .running:
            callStatus = "通话中"
            isCalling = true
        case .paused:
            callStatus = "已暂停"
            isCalling = true
        case .error:
            callStatus = "呼叫错误"
            isCalling = false
        case .ended, .released:
            callStatus = "已结束"
            isCalling = false
        default:
            callStatus = "未知状态"
            isCalling = false
        }
        
        isMuted = sipManager.isMuted
        isSpeakerOn = sipManager.isSpeakerEnabled
    }
    
    private func unregister() {
        // 实现注销功能
        addLog("SIP日志: 正在注销SIP账户")
        
        SipManager.shared.configureSipAccount(
            username: "",
            password: "",
            domain: "",
            port: "",
            transport: "UDP"
        )
        
        status = "已注销"
        isRegistered = false
        
        // 清除所有计时器
        registrationTimer?.invalidate()
        registrationTimer = nil
    }
    
    private func endCall() {
        addLog("SIP日志: 正在结束通话")
        sipManager.terminateCall()
    }
    
    private func toggleMute() {
        isMuted = !isMuted
        sipManager.toggleMute(isMuted)
        addLog("SIP日志: 麦克风 \(isMuted ? "已静音" : "已取消静音")")
    }
    
    private func toggleSpeaker() {
        isSpeakerOn = !isSpeakerOn
        sipManager.toggleSpeaker(isSpeakerOn)
        addLog("SIP日志: 扬声器 \(isSpeakerOn ? "已开启" : "已关闭")")
    }
    
    private func diagnoseAudioDevices() {
        addLog("SIP日志: 诊断音频设备...")
        // 获取音频会话状态
        let session = AVAudioSession.sharedInstance()
        
        do {
            addLog("当前音频设备:")
            addLog("- 当前输出路由: \(session.currentRoute.outputs.map { $0.portName }.joined(separator: ", "))")
            if let inputs = session.availableInputs {
                addLog("- 可用输入设备: \(inputs.map { $0.portName }.joined(separator: ", "))")
            }
            
            // 尝试重置并重新初始化音频会话
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
            
            addLog("音频会话已配置: 模式=\(session.mode.rawValue), 采样率=\(session.sampleRate)Hz")
            
            // 尝试重新加载Linphone音频设备
            sipManager.reloadAudioDevices()
            addLog("已重新加载音频设备")
        } catch {
            addLog("音频诊断错误: \(error)")
        }
    }
    
    private func resetSipSettings() {
        server = "116.198.199.38"
        port = "5060"
        username = "5001"
        password = "5001"
        callTarget = "5000"
        transportType = "UDP"
        
        // 注销当前SIP注册
        unregister()
        
        // 保存重置后的设置
        saveSettings()
        
        addLog("SIP日志: 已重置SIP设置")
    }
    
    private func setSipCallback() {
        // 不需要再调用 setupCallback，因为现在我们使用通知中心
        // 直接确保通知观察者已设置
        setupNotificationObservers()
    }
    
    // 添加设置通知观察者的方法
    private func setupNotificationObservers() {
        let notifications = SipTestViewNotifications()
        
        NotificationCenter.default.addObserver(forName: notifications.registrationSuccess, object: nil, queue: .main) { _ in
            self.updateStatus("已注册")
            self.updateRegistrationState(isRegistered: true, isRegistering: false)
        }
        
        NotificationCenter.default.addObserver(forName: notifications.registrationFailed, object: nil, queue: .main) { notification in
            if let reason = notification.object as? String {
                self.updateStatus("注册失败: \(reason)")
                self.updateRegistrationState(isRegistered: false, isRegistering: false)
            }
        }
        
        NotificationCenter.default.addObserver(forName: notifications.callFailed, object: nil, queue: .main) { notification in
            if let reason = notification.object as? String {
                self.updateCallStatus("通话失败: \(reason)")
                self.updateCallingState(false)
            }
        }
        
        NotificationCenter.default.addObserver(forName: notifications.callEstablished, object: nil, queue: .main) { _ in
            self.updateCallStatus("通话中")
            self.updateCallingState(true)
        }
        
        NotificationCenter.default.addObserver(forName: notifications.callEnded, object: nil, queue: .main) { _ in
            self.updateCallStatus("通话结束")
            self.updateCallingState(false)
        }
        
        NotificationCenter.default.addObserver(forName: notifications.sipRegistrationStateChanged, object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let isSuccess = userInfo["isSuccess"] as? Bool,
               let message = userInfo["message"] as? String {
                self.updateStatus(isSuccess ? "已注册" : "注册失败: \(message)")
                self.updateRegistrationState(isRegistered: isSuccess, isRegistering: false)
            }
        }
        
        NotificationCenter.default.addObserver(forName: notifications.callQualityChanged, object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let quality = userInfo["quality"] as? Float {
                self.updateAudioQuality("\(Int(quality * 100))%")
            }
        }
    }
    
    // 添加更新方法
    func updateStatus(_ newStatus: String) {
        status = newStatus
    }
    
    func updateCallStatus(_ newStatus: String) {
        callStatus = newStatus
    }
    
    func updateRegistrationState(isRegistered: Bool, isRegistering: Bool) {
        self.isRegistered = isRegistered
        self.isRegistering = isRegistering
    }
    
    func updateCallingState(_ isCalling: Bool) {
        self.isCalling = isCalling
    }
    
    func updateAudioQuality(_ quality: String) {
        audioQuality = quality
    }
}

// 添加通知名称结构体
struct SipTestViewNotifications {
    let registrationSuccess = NSNotification.Name("SipRegistrationSuccessNotification")
    let registrationFailed = NSNotification.Name("SipRegistrationFailedNotification")
    let incomingCall = NSNotification.Name("SipIncomingCallNotification")
    let callFailed = NSNotification.Name("SipCallFailedNotification")
    let callEstablished = NSNotification.Name("SipCallEstablishedNotification")
    let callEnded = NSNotification.Name("SipCallEndedNotification")
    let sipRegistrationStateChanged = NSNotification.Name("SipRegistrationStateChangedNotification")
    let callQualityChanged = NSNotification.Name("SipCallQualityChangedNotification")
}

// SipTestView的回调处理类
class SipTestViewCallback: SipManagerCallback {
    // 使用闭包处理回调
    private let onRegistrationSuccessHandler: () -> Void
    private let onRegistrationFailedHandler: (String) -> Void
    private let onIncomingCallHandler: (linphonesw.Call, String) -> Void
    private let onCallFailedHandler: (String) -> Void
    private let onCallEstablishedHandler: () -> Void
    private let onCallEndedHandler: () -> Void
    private let onSipRegistrationStateChangedHandler: (Bool, String) -> Void
    private let onCallQualityChangedHandler: (Float, String) -> Void
    
    init(
        onRegistrationSuccess: @escaping () -> Void,
        onRegistrationFailed: @escaping (String) -> Void,
        onIncomingCall: @escaping (linphonesw.Call, String) -> Void,
        onCallFailed: @escaping (String) -> Void,
        onCallEstablished: @escaping () -> Void,
        onCallEnded: @escaping () -> Void,
        onSipRegistrationStateChanged: @escaping (Bool, String) -> Void,
        onCallQualityChanged: @escaping (Float, String) -> Void
    ) {
        self.onRegistrationSuccessHandler = onRegistrationSuccess
        self.onRegistrationFailedHandler = onRegistrationFailed
        self.onIncomingCallHandler = onIncomingCall
        self.onCallFailedHandler = onCallFailed
        self.onCallEstablishedHandler = onCallEstablished
        self.onCallEndedHandler = onCallEnded
        self.onSipRegistrationStateChangedHandler = onSipRegistrationStateChanged
        self.onCallQualityChangedHandler = onCallQualityChanged
    }
    
    func onRegistrationSuccess() {
        DispatchQueue.main.async {
            self.onRegistrationSuccessHandler()
        }
    }
    
    func onRegistrationFailed(reason: String) {
        DispatchQueue.main.async {
            self.onRegistrationFailedHandler(reason)
        }
    }
    
    func onIncomingCall(call: linphonesw.Call, caller: String) {
        DispatchQueue.main.async {
            // 发送通知而不是直接回调
            NotificationCenter.default.post(
                name: NSNotification.Name("IncomingCallNotification"),
                object: nil,
                userInfo: ["caller": caller, "call": call]
            )
            self.onIncomingCallHandler(call, caller)
        }
    }
    
    func onCallFailed(reason: String) {
        DispatchQueue.main.async {
            self.onCallFailedHandler(reason)
        }
    }
    
    func onCallEstablished() {
        DispatchQueue.main.async {
            self.onCallEstablishedHandler()
        }
    }
    
    func onCallEnded() {
        DispatchQueue.main.async {
            self.onCallEndedHandler()
        }
    }
    
    func onSipRegistrationStateChanged(isSuccess: Bool, message: String) {
        DispatchQueue.main.async {
            self.onSipRegistrationStateChangedHandler(isSuccess, message)
        }
    }
    
    func onCallQualityChanged(quality: Float, message: String) {
        DispatchQueue.main.async {
            self.onCallQualityChangedHandler(quality, message)
        }
    }
}

struct SipTestView_Previews: PreviewProvider {
    static var previews: some View {
        SipTestView()
    }
}
