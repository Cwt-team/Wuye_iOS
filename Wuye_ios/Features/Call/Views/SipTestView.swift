import SwiftUI
import Combine
import linphonesw
import AVFoundation

struct SipTestView: View {
    @State private var server: String = UserDefaults.standard.string(forKey: "sipDomain") ?? "116.198.199.38"
    @State private var port: String = UserDefaults.standard.string(forKey: "sipPort") ?? "5060"
    @State private var username: String = UserDefaults.standard.string(forKey: "sipUsername") ?? "5001"
    @State private var password: String = UserDefaults.standard.string(forKey: "sipPassword") ?? "5001"
    @State private var callTarget: String = UserDefaults.standard.string(forKey: "sipTarget") ?? "5000"
    @State private var transportType: String = UserDefaults.standard.string(forKey: "sipTransport") ?? "UDP"
    
    @State private var status: String = "未注册"
    @State private var callStatus: String = "空闲"
    @State private var isRegistering: Bool = false
    @State private var isCalling: Bool = false
    @State private var isRegistered: Bool = false
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
    @State private var audioQuality: String = "未知"
    @State private var callLatency: String = "未知"
    
    @ObservedObject private var sipManager = SipManager.shared
    
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
                    Section(header: Text("呼叫测试")) {
                        TextField("呼叫目标号码", text: $callTarget)
                            .keyboardType(.phonePad)
                        
                        HStack {
                            Text("通话状态:")
                            Spacer()
                            Text(callStatus)
                                .foregroundColor(getCallStatusColor())
                        }
                        
                        Button(action: {
                            if isCalling {
                                endCall()
                            } else {
                                startCall()
                            }
                        }) {
                            HStack {
                                Text(isCalling ? "结束通话" : "发起呼叫")
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(isCalling ? .red : .blue)
                            }
                        }
                        
                        if isCalling {
                            VStack(spacing: 10) {
                                HStack {
                                    Button(action: { toggleMute() }) {
                                        VStack {
                                            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                                .padding(12)
                                                .background(isMuted ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                                                .clipShape(Circle())
                                            Text(isMuted ? "取消静音" : "静音")
                                                .font(.caption)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Spacer()
                                    
                                    Button(action: { toggleSpeaker() }) {
                                        VStack {
                                            Image(systemName: isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                                .padding(12)
                                                .background(isSpeakerOn ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                                .clipShape(Circle())
                                            Text(isSpeakerOn ? "关闭扬声器" : "扬声器")
                                                .font(.caption)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Spacer()
                                    
                                    // 新增的重新连接按钮
                                    Button(action: { reconnectAudio() }) {
                                        VStack {
                                            Image(systemName: "arrow.clockwise")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                                .padding(12)
                                                .background(Color.green.opacity(0.2))
                                                .clipShape(Circle())
                                            Text("重连音频")
                                                .font(.caption)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    
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
                
                // 设置回调
                setSipCallback()
                
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
    
    private func startCall() {
        saveSettings()
        addLog("SIP日志: 正在发起呼叫: \(callTarget)")
        sipManager.call(recipient: callTarget)
        
        // 模拟一些通话信息（真实应用中应从SIP会话中获取）
        updateCallInfo()
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
    
    // 新增的重新连接音频功能
    private func reconnectAudio() {
        addLog("SIP日志: 尝试重新连接音频...")
        
        do {
            try sipManager.prepareAudioForCall()
            addLog("SIP日志: 音频设备已重新配置")
        } catch {
            addLog("SIP日志: 重新连接音频失败: \(error)")
        }
    }
    
    // 模拟获取通话信息
    private func updateCallInfo() {
        // 这些值应该从实际网络和SIP会话中获取
        networkType = "4G/WiFi"
        localIP = "192.168.1.xxx"
        signalStrength = Int.random(in: 3...5)
        audioQuality = ["优良", "良好", "一般"].randomElement()!
        callLatency = "\(Int.random(in: 50...200))ms"
        
        // 在实际通话中定期更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if isCalling {
                updateCallInfo()
            }
        }
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
        sipManager.setSipCallback(SipCallbackHandler(
            onRegistrationSuccess: {
                DispatchQueue.main.async {
                    isRegistering = false
                    updateStatus()
                    addLog("SIP日志: SIP注册已成功")
                }
            },
            onRegistrationFailed: { reason in
                DispatchQueue.main.async {
                    isRegistering = false
                    updateStatus()
                    addLog("SIP日志: SIP注册失败: \(reason)")
                }
            },
            onIncomingCall: { call, caller in
                DispatchQueue.main.async {
                    updateStatus()
                    addLog("SIP日志: 收到来电: \(caller)")
                }
            },
            onCallEstablished: {
                DispatchQueue.main.async {
                    updateStatus()
                    addLog("SIP日志: 通话已建立")
                }
            },
            onCallFailed: { reason in
                DispatchQueue.main.async {
                    updateStatus()
                    addLog("SIP日志: 呼叫失败: \(reason)")
                }
            },
            onCallEnded: {
                DispatchQueue.main.async {
                    updateStatus()
                    addLog("SIP日志: 通话已结束")
                }
            }
        ))
    }
}

// 回调处理类
class SipCallbackHandler: SipManagerCallback {
    private let registrationSuccessHandler: () -> Void
    private let registrationFailedHandler: (String) -> Void
    private let incomingCallHandler: (linphonesw.Call, String) -> Void
    private let callEstablishedHandler: () -> Void
    private let callFailedHandler: (String) -> Void
    private let callEndedHandler: () -> Void
    
    init(
        onRegistrationSuccess: @escaping () -> Void,
        onRegistrationFailed: @escaping (String) -> Void,
        onIncomingCall: @escaping (linphonesw.Call, String) -> Void,
        onCallEstablished: @escaping () -> Void,
        onCallFailed: @escaping (String) -> Void,
        onCallEnded: @escaping () -> Void
    ) {
        self.registrationSuccessHandler = onRegistrationSuccess
        self.registrationFailedHandler = onRegistrationFailed
        self.incomingCallHandler = onIncomingCall
        self.callEstablishedHandler = onCallEstablished
        self.callFailedHandler = onCallFailed
        self.callEndedHandler = onCallEnded
    }
    
    // 实现SipManagerCallback协议
    func onRegistrationSuccess() {
        registrationSuccessHandler()
    }
    
    func onRegistrationFailed(reason: String) {
        registrationFailedHandler(reason)
    }
    
    func onIncomingCall(call: linphonesw.Call, caller: String) {
        incomingCallHandler(call, caller)
    }
    
    func onCallEstablished() {
        callEstablishedHandler()
    }
    
    func onCallFailed(reason: String) {
        callFailedHandler(reason)
    }
    
    func onCallEnded() {
        callEndedHandler()
    }
    
    // 添加缺少的协议方法
    func onSipRegistrationStateChanged(isSuccess: Bool, message: String) {
        print("SIP注册状态: \(isSuccess ? "成功" : "失败") - \(message)")
        if isSuccess {
            registrationSuccessHandler()
        } else {
            registrationFailedHandler(message)
        }
    }
    
    func onCallQualityChanged(quality: Float, message: String) {
        print("通话质量变更: \(quality) - \(message)")
    }
}

struct SipTestView_Previews: PreviewProvider {
    static var previews: some View {
        SipTestView()
    }
} 