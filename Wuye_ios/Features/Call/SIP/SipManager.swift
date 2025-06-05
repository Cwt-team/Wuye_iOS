import Foundation
import UIKit
import AVFoundation
import linphonesw
// 直接导入linphone模块以解决潜在问题
import linphone
// 导入套接字相关库
import Darwin.POSIX.sys.socket
import Darwin.POSIX.netinet.`in`
import Darwin.POSIX.arpa.inet
import Darwin.POSIX.netdb  // 用于getnameinfo函数
// 确保在使用Call.State时引用正确的命名空间


// 定义LinphoneError
enum LinphoneError: Error {
    case exception(result: String)
}

// MARK: - SIP States

enum CallState {
    case idle, incoming, outgoingInit, ringing, connected, running, paused, ended, released, error
}

enum RegState {
    case none, progress, ok, failed, cleared
}

// MARK: - SIP Callback Protocol

protocol SipManagerCallback: AnyObject {
    func onRegistrationSuccess()
    func onRegistrationFailed(reason: String)
    func onIncomingCall(call: linphonesw.Call, caller: String)
    func onCallFailed(reason: String)
    func onCallEstablished()
    func onCallEnded()
    func onSipRegistrationStateChanged(isSuccess: Bool, message: String)
    func onCallQualityChanged(quality: Float, message: String)
}

// MARK: - SIP Manager

class SipManager: ObservableObject {
    static let shared = SipManager()

    @Published var registrationState: RegState = .none
    @Published var callState: CallState = .idle
    @Published var isMuted: Bool = false
    @Published var isSpeakerEnabled: Bool = false

    private var core: Core?
    private var factory: Factory?
    @Published var currentCall: linphonesw.Call?
    private var callback: SipManagerCallback?
    private var coreDelegate: CoreDelegateStub?

    private var CoreTimer = Timer()

    // 修改为 UIView? 类型，并添加 didSet 观察者
    @Published var localVideoView: UIView? {
        didSet {
            print("【SIP日志】SipManager.localVideoView didSet: \(localVideoView != nil ? "非空" : "空")")
            if let core = core {
                core.nativePreviewWindow = localVideoView
                print("【SIP日志】core.nativePreviewWindow 已更新为 \(localVideoView != nil ? "非空" : "空")")
            }
        }
    }
    @Published var remoteVideoView: UIView? {
        didSet {
            print("【SIP日志】SipManager.remoteVideoView didSet: \(remoteVideoView != nil ? "非空" : "空")")
            if let core = core {
                core.nativeVideoWindow = remoteVideoView
                print("【SIP日志】core.nativeVideoWindow 已更新为 \(remoteVideoView != nil ? "非空" : "空")")
            }
        }
    }

    private init() {
        print("[SipManager] 开始初始化")
        initializeLinphone()
    }

    // MARK: - Initialization

    private func initializeLinphone() {
        do {
            print("正在初始化Linphone...")
            
            // 使用最新API配置日志
            LoggingService.Instance.logLevel = LogLevel.Debug
            Factory.Instance.enableLogCollection(state: LogCollectionState.Enabled)
            
            // 使用C API创建Factory和Core
            print("初始化Factory和Core...")
            factory = Factory.Instance
            
            // 创建Core实例
            let createdCore = try factory?.createCore(configPath: nil, factoryConfigPath: nil, systemContext: nil)
            
            // 只有当 Core 成功创建后，才继续进行后续配置和代理设置
            if let unwrappedCore = createdCore {
                core = unwrappedCore // 赋值给 SipManager 的 core 属性
                print("Linphone Core创建成功")
                
                // 配置Core
                configureCore()
                
                // 配置编解码器
                configureCodecs()
                
                // 启动Core
                try unwrappedCore.start()
                print("Linphone Core启动成功")
                
                // === 延迟 CoreDelegateStub 的创建和添加，在 Core 启动后进行 ===
                print("设置Core代理...")
                let newCoreDelegate = CoreDelegateStub(
                    onRegistrationStateChanged: { [weak self] (c: Core, proxyConfig: ProxyConfig, state: RegistrationState, message: String) in
                        self?.handleRegistrationStateChanged(state: state, message: message)
                    },
                    onCallStateChanged: { [weak self] (c: Core, call: linphonesw.Call, state: linphonesw.Call.State, message: String) in
                        self?.handleCallStateChanged(call: call, state: state, message: message)
                    }
                )
                self.coreDelegate = newCoreDelegate
                unwrappedCore.addDelegate(delegate: newCoreDelegate)
                print("Core代理设置成功。")
                // ==========================================================
                
                // 启动Core迭代计时器
                startCoreTimer()
            } else {
                print("Linphone Core创建失败，core为nil。")
                // Core 未成功创建，更新注册状态为失败
                DispatchQueue.main.async {
                    self.registrationState = .failed
                    self.callback?.onRegistrationFailed(reason: "Linphone Core初始化失败")
                }
            }
        } catch {
            print("Initialization error: \(error)")
            // 捕获 Core 初始化过程中的错误，并更新注册状态
            DispatchQueue.main.async {
                self.registrationState = .failed
                self.callback?.onRegistrationFailed(reason: "Linphone Core初始化错误: \(error.localizedDescription)")
            }
        }
    }
    
    private func configureCore() {
        guard let core = core else { return }
        
        print("配置Core...")
        
        // 检查网络可达性并设置
        let isReachable = checkNetworkReachability()
        core.networkReachable = isReachable
        print("网络可达性状态: \(isReachable ? "可达" : "不可达")")
        
        // 配置NAT策略 - 使用C API
        let natPolicy = try? core.createNatPolicy()
        natPolicy?.stunEnabled = true
        natPolicy?.iceEnabled = true  // 启用ICE以改善NAT穿透
        natPolicy?.stunServer = "stun.l.google.com:19302"
        core.natPolicy = natPolicy
        print("NAT策略已配置: STUN=\(natPolicy?.stunServer ?? "none"), ICE=enabled")

        // 配置视频策略
        core.videoActivationPolicy?.automaticallyInitiate = false
        core.videoActivationPolicy?.automaticallyAccept = false
        print("视频策略已配置: 自动发起=false, 自动接受=false")

        // 设置网络可达性
        core.networkReachable = true
        print("已设置网络可达性")

        // 配置RTP超时
        if let config = core.config {
            // 设置RTP配置
            config.setInt(section: "rtp", key: "timeout", value: 30)
            print("已设置RTP超时: 30秒")
            
            // 设置端口范围
            config.setInt(section: "rtp", key: "audio_rtp_port", value: 7078)
            config.setInt(section: "rtp", key: "audio_rtp_port_max", value: 7178)
            print("已设置RTP端口范围: 7078-7178")
            
            // 禁用LIME加密警告
            config.setBool(section: "lime", key: "enabled", value: false)
            print("已禁用LIME加密")
            
            // 配置SIP连接超时
            config.setInt(section: "sip", key: "sip_tcp_transport_timeout", value: 15)
            config.setInt(section: "sip", key: "dns_timeout", value: 15)
            print("已设置SIP连接超时: 15秒")
            
            // 设置日志级别
            config.setInt(section: "misc", key: "log_level", value: 3) // ORTP_MESSAGE
            print("已设置日志级别: 3 (ORTP_MESSAGE)")
            
            // 禁用模拟器音频
            #if targetEnvironment(simulator)
            config.setBool(section: "sound", key: "disable_audio_device", value: true)
            print("已禁用模拟器音频设备")
            #endif
        }
        
        // 启用静态音频包大小 - 改善音频质量
        core.useInfoForDtmf = true
        core.keepAliveEnabled = true  // 保持连接
    }

    // 检查网络可达性
    private func checkNetworkReachability() -> Bool {
        // 这只是一个简单的网络检查，实际项目可能需要更复杂的网络检测
        var reachable = false
        
        // 尝试设置一个简单的socket连接
        let hostName = "8.8.8.8" // Google DNS
        let port: UInt16 = 53 // DNS端口
        
        let socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        if socket != -1 {
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            addr.sin_addr.s_addr = inet_addr(hostName)
            
            let addrLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(socket, $0, addrLength)
                }
            }
            
            if bindResult != -1 {
                reachable = true
            }
            
            close(socket)
        }
        
        print("网络可达性检查结果: \(reachable ? "网络正常" : "网络不可用")")
        return reachable
    }

    private func configureCodecs() {
        guard let core = core else { return }
        print("开始配置音频编解码器...")
        
        // 禁用所有音频编解码器
        for payload in core.audioPayloadTypes {
            payload.enable(enabled: false)
        }
        // 启用常用音频编解码器
        let enabledAudioCodecs = ["PCMU", "PCMA", "G729"]
        for codec in enabledAudioCodecs {
            for payload in core.audioPayloadTypes {
                if payload.mimeType.lowercased() == codec.lowercased() {
                    payload.enable(enabled: true)
                    print("已启用音频编解码器: \(payload.mimeType) (\(payload.clockRate)Hz)")
                }
            }
        }

        // 启用常用视频编解码器
        print("开始配置视频编解码器...")
        
        // 先禁用所有视频编解码器
        for payload in core.videoPayloadTypes {
            payload.enable(enabled: false)
        }

        // 只启用H264和VP8
        let enabledVideoCodecs = ["H264", "VP8"]
        for codec in enabledVideoCodecs {
            for payload in core.videoPayloadTypes {
                if payload.mimeType.lowercased() == codec.lowercased() {
                    payload.enable(enabled: true)
                    print("已启用视频编解码器: \(payload.mimeType) (\(payload.clockRate)Hz)")
                }
            }
        }

        print("当前所有视频payload状态：")
        for payload in core.videoPayloadTypes {
            print("视频payload: \(payload.mimeType) enabled: \(payload.enabled())")
        }
    }
    
    // MARK: - Core Delegate Handlers
    
    private func handleCallStateChanged(call: linphonesw.Call, state: linphonesw.Call.State, message: String) {
        let remote = call.remoteAddress?.asString() ?? "未知"
        let stateStr = String(describing: state)
        let timeStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("【SIP信令日志】[\(timeStr)] CallStateChanged: 状态=\(stateStr), 对端=\(remote), message=\(message)")
        if state == .IncomingReceived {
            print("【SIP日志】 已收到来电信令，主叫: \(remote)")
            print("【调试】收到来电，主叫: \(call.remoteAddress?.asString() ?? "未知")")
        }
        
        DispatchQueue.main.async {
            switch state {
            case .IncomingReceived:
                self.currentCall = call
                self.callState = .incoming
                if let caller = call.remoteAddress?.username {
                    self.callback?.onIncomingCall(call: call, caller: caller)
                }
            case .OutgoingInit:
                self.callState = .outgoingInit
            case .OutgoingRinging:
                self.callState = .ringing
            case .Connected:
                self.callState = .connected
                self.callback?.onCallEstablished()
            case .StreamsRunning:
                self.callState = .running
                // 确保视频捕获和显示在媒体流运行时启用
                if let core = self.core {
                    core.videoCaptureEnabled = true
                    core.videoDisplayEnabled = true
                    print("【SIP日志】视频捕获和显示已在 StreamsRunning 状态下启用。")
                    print("【调试】当前 core.nativePreviewWindow 是否已设置: \(core.nativePreviewWindow != nil ? "是" : "否")")
                    print("【调试】当前 core.nativeVideoWindow 是否已设置: \(core.nativeVideoWindow != nil ? "是" : "否")")
                    // 额外打印当前视图实例的地址，与 LinphoneVideoView 中的地址进行对比
                    if let localView = self.localVideoView {
                        print("【调试】SipManager 持有的本地视图实例: \(ObjectIdentifier(localView))")
                    }
                    if let remoteView = self.remoteVideoView {
                        print("【调试】SipManager 持有的远端视图实例: \(ObjectIdentifier(remoteView))")
                    }
                }
            case .Paused:
                self.callState = .paused
            case .End:
                self.callState = .ended
                self.callback?.onCallEnded()
                self.currentCall = nil // 挂断后清空当前通话
            case .Error:
                self.callState = .error
                self.callback?.onCallFailed(reason: message)
                self.currentCall = nil // 错误后清空当前通话
            default:
                break
            }
        }
    }
    
    private func handleRegistrationStateChanged(state: linphonesw.RegistrationState, message: String) {
        print("注册状态变更: \(state) (\(message))")
        
        DispatchQueue.main.async {
            // 将 linphonesw.RegistrationState 转换为我们自定义的 RegState
            let regState: RegState
            switch state {
            case .None: regState = .none
            case .Progress: regState = .progress
            case .Ok: regState = .ok
            case .Failed: regState = .failed
            case .Cleared: regState = .cleared
            default: regState = .none // 添加 default 处理未知情况
            }
            
            self.registrationState = regState // 赋值给 @Published 属性
            
            switch regState { // 这里使用转换后的 regState
            case .ok:
                print("[SIP] 注册成功! 服务器已确认注册")
                self.callback?.onRegistrationSuccess()
                
            case .failed:
                print("[SIP] 注册失败! 原因: \(message)")
                self.callback?.onRegistrationFailed(reason: message)
                
            case .progress:
                print("[SIP] 注册进行中...")
                
            case .cleared:
                print("[SIP] 注册已清除")
                
            case .none:
                print("[SIP] 未注册状态")
                
            // default 已经包含在 regState 的转换中，此处可以省略或留空
            }
        }
    }

    // MARK: - SIP Account Configuration

    func configureSipAccount(username: String, password: String, domain: String, port: String, transport: String) {
        print("[SIP] 开始配置SIP账户 - 用户名: \(username), 域名: \(domain), 端口: \(port), 传输方式: \(transport)")
        
        // 设置状态为progress
        DispatchQueue.main.async {
            if !username.isEmpty && !domain.isEmpty {
                // 只有在执行注册时才设置为progress状态
                self.registrationState = .progress
            }
        }
        
        guard let core = self.core else {
            print("[SIP] 配置SIP账户失败：核心未初始化")
            DispatchQueue.main.async {
                self.registrationState = .failed
                self.callback?.onRegistrationFailed(reason: "核心未初始化")
            }
            return
        }
        
        let factory = Factory.Instance
        
        do {
            // 1. 清除现有账户和认证信息
            print("[SIP] 清除现有SIP账户配置...")
            for authInfo in core.authInfoList {
                core.removeAuthInfo(info: authInfo)
            }
            
            while let proxyConfig = core.proxyConfigList.first {
                core.removeProxyConfig(config: proxyConfig)
            }
            
            // 如果用户名为空，则返回（用于注销）
            if username.isEmpty || domain.isEmpty {
                print("[SIP] 用户名或域名为空，执行注销操作")
                DispatchQueue.main.async {
                    self.registrationState = .cleared
                }
                return
            }
            
            // 2. 创建新的认证信息
            print("[SIP] 创建新的SIP认证信息")
            let authInfo = try factory.createAuthInfo(
                username: username,
                userid: username,
                passwd: password,
                ha1: "",
                realm: "",
                domain: domain)
            
            // 3. 添加认证信息到核心
            core.addAuthInfo(info: authInfo)
            
            // 4. 创建代理配置
            print("[SIP] 创建SIP代理配置")
            let proxyConfig = try core.createProxyConfig()
            
            // 5. 设置注册参数
            // 创建身份地址
            let identityAddress = try factory.createAddress(addr: "sip:\(username)@\(domain)")
            print("[SIP] 设置身份地址: \(identityAddress.asString())")
            try proxyConfig.setIdentityaddress(newValue: identityAddress)
            
            // 设置服务器地址
            let transportType = transport.uppercased() == "UDP" ? "UDP" : "TCP"
            let serverAddress = "sip:\(domain):\(port);transport=\(transportType)"
            print("[SIP] 设置服务器地址: \(serverAddress)")
            try proxyConfig.setServeraddr(newValue: serverAddress)
            
            // 设置联系地址参数以确保正确的呼叫路由
            let localIp = getLocalIPAddress() // 获取有效的本地IP地址
            if let localIp = localIp, !localIp.isEmpty {
                // 直接设置联系参数和URI参数
                proxyConfig.contactParameters = ""  // 清空默认参数
                
                // 使用唯一端口号以避免冲突
                let uniquePort = Int.random(in: 10000...60000)
                proxyConfig.contactUriParameters = "transport=\(transportType);port=\(uniquePort)"
                
                print("[SIP] 使用本地IP设置联系参数: IP=\(localIp), 端口=\(uniquePort), 传输=\(transportType)")
            }
            
            // 设置其他参数
            proxyConfig.registerEnabled = true
            proxyConfig.expires = 3600 // 注册有效期1小时
            
            // 增加诊断信息
            print("[SIP] 诊断信息:")
            print("[SIP] - 身份地址: \(identityAddress.asString())")
            print("[SIP] - 服务器地址: \(serverAddress)")
            print("[SIP] - 传输方式: \(transportType)")
            print("[SIP] - 过期时间: \(proxyConfig.expires)秒")
            
            // 设置最大重试次数（可选，用于快速失败)
            if let config = core.config {
                config.setInt(section: "sip", key: "register_retry_count", value: 3)
            }
            
            // 6. 添加代理配置到核心并设为默认
            try core.addProxyConfig(config: proxyConfig)
            core.defaultProxyConfig = proxyConfig
            
            print("[SIP] SIP账户配置完成，等待注册结果...")
            
        } catch {
            print("[SIP] SIP账户配置错误: \(error)")
            DispatchQueue.main.async {
                self.registrationState = .failed
                self.callback?.onRegistrationFailed(reason: error.localizedDescription)
            }
        }
    }

    // MARK: - Call Management

    // ====== 1. 移除/注释掉主动呼叫相关方法 ======

    // 删除或注释掉
    // func call(recipient: String) { ... }
    // private func makeNewCall(recipient: String) { ... }

    // ====== 2. 保留被叫相关方法 ======

    // 保留
    func acceptCall() {
        guard let currentCall = self.currentCall, let core = self.core else {
            print("[SipManager] acceptCall: currentCall或core为nil，无法接听。")
            return
        }
        do {
            let params = try core.createCallParams(call: currentCall)
            params.videoEnabled = true
            
            // 确保视频激活策略允许自动发起和接受视频
            core.videoActivationPolicy?.automaticallyInitiate = true
            core.videoActivationPolicy?.automaticallyAccept = true
            print("【SIP日志】已在 acceptCall 中设置 videoActivationPolicy 为自动发起和接受。")

            setupFrontCamera()
            let remote = currentCall.remoteAddress?.asString() ?? "未知"
            print("【SIP信令日志】发送200 OK（接听来电），对端=\(remote)")
            try currentCall.acceptWithParams(params: params)
            print("【SIP日志】成功发送接听请求。")
        } catch {
            print("接听视频通话失败: \(error)")
        }
    }
            
    // 终止当前通话
    func terminateCall() {
        print("[SipManager] terminateCall 被调用。")
        if let call = currentCall {
            print("[SipManager] currentCall 存在，状态为: \(call.state)")
            do {
                let remote = call.remoteAddress?.asString() ?? "未知"
                print("【SIP信令日志】发送BYE，对端=\(remote)")
                try call.terminate()
                print("【SIP日志】成功发送挂断请求。")
                self.currentCall = nil
                self.callState = .idle
            } catch {
                print("终止通话失败: \(error)")
            }
        } else {
            print("[SipManager] terminateCall: currentCall 为 nil，无需挂断。")
            self.callState = .idle
        }
    }

    func toggleMute(_ muted: Bool) {
        guard let core = core else { return }
        isMuted = muted
        core.micEnabled = !muted
        print("麦克风状态: \(muted ? "已静音" : "已取消静音")")
    }

    func toggleSpeaker(_ enabled: Bool) {
        isSpeakerEnabled = enabled
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 使用正确的选项组合
            var options: AVAudioSession.CategoryOptions = [.allowBluetooth, .allowBluetoothA2DP]
            
            if enabled {
                options.insert(.defaultToSpeaker)
                print("切换到扬声器模式")
            } else {
                print("切换到听筒模式")
            }
            
            // 保持playAndRecord类别，但更新选项
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
            
            // 确保会话仍然处于活动状态
            if !session.isOtherAudioPlaying {
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            }
            
            // 重新检查音频路由
            let outputs = session.currentRoute.outputs.map { $0.portName }.joined(separator: ", ")
            print("当前音频输出路由: \(outputs)")
        } catch {
            print("扬声器切换错误: \(error)")
        }
    }

    func setCallback(_ callback: SipManagerCallback) {
        self.callback = callback
    }

    // MARK: - Public Methods
    
    // 重新加载音频设备
    func reloadAudioDevices() {
        if let core = self.core {
            core.reloadSoundDevices()
            print("[SIP] 已重新加载音频设备")
        }
    }
    
    // 获取Linphone版本信息
    func getVersionInfo() -> String {
        // 使用 linphone_core_get_version() 获取版本信息
        if let versionStr = linphone_core_get_version() {
            return "Linphone SDK \(String(cString: versionStr))"
        }
        return "Linphone SDK 5.2.114"  // 直接返回已知版本
    }

    // 获取Core对象用于诊断
    func getCore() -> Core? {
        return core
    }

    // MARK: - Permissions

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                print("麦克风权限状态: \(granted ? "已授权" : "已拒绝")")
                completion(granted)
            }
        }
    }

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }
    
    // 确保在退出时释放资源
    deinit {
        print("SipManager正在释放资源...")
        CoreTimer.invalidate()
        
        // 终止当前通话
        if let call = currentCall {
            let currentState = call.state
            if currentState != linphonesw.Call.State.End && currentState != linphonesw.Call.State.Released {
                try? call.terminate()
            }
        }
        
        // 移除代理
        if let core = core, let delegate = coreDelegate {
            core.removeDelegate(delegate: delegate)
        }
        
        // 停止核心
        try? core?.stop()
        
        // 释放音频会话
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Helper Methods

    private var isRegistered: Bool {
        guard let core = self.core, let defaultProxyConfig = core.defaultProxyConfig else {
            return false
        }
        return defaultProxyConfig.state == RegistrationState.Ok
    }

    private func requestMicrophoneAndCameraPermissions(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("麦克风权限已获得")
                    completion(true)
                } else {
                    print("麦克风权限被拒绝")
                    completion(false)
                }
            }
        }
    }

    private func startCoreTimer() {
        // 创建定时器来迭代Core
        CoreTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self = self, let core = self.core else { return }
            
            // 迭代Core以处理事件
            core.iterate()
        }
    }

    // 添加一个获取本地IP地址的辅助方法
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    // 检查接口是否为en0（WiFi）或en1（有线网络）
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" || name == "pdp_ip0" {  // pdp_ip0是蜂窝数据
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                        let ipAddress = String(cString: hostname)
                        // 只返回IPv4地址
                        if addrFamily == UInt8(AF_INET) && !ipAddress.contains(":") {
                            address = ipAddress
                            break  // 找到一个合适的IPv4地址就退出
                        }
                    }
                }
            }
            
            freeifaddrs(ifaddr)
        }
        
        return address
    }

    // 刷新SIP注册
    func refreshRegistrations() {
        print("[SipManager] 开始刷新SIP注册...")
        
        guard let core = core else {
            print("[SipManager] 无法刷新注册：核心未初始化")
            return
        }
        
        if let proxyConfig = core.defaultProxyConfig {
            // 检查当前注册状态
            let currentState = proxyConfig.state
            print("[SipManager] 当前注册状态: \(currentState)")
            
            // 只有当注册状态不为progress时才刷新
            if currentState != .Progress {
                do {
                    try proxyConfig.refreshRegister()
                    print("[SipManager] 注册刷新请求已发送")
                } catch {
                    print("[SipManager] 刷新注册失败: \(error)")
                }
            } else {
                print("[SipManager] 当前正在注册中，跳过刷新")
            }
        } else {
            print("[SipManager] 没有默认代理配置，无法刷新注册")
        }
    }

    // 添加模拟器专用方法
    #if targetEnvironment(simulator)
    /// 模拟器环境中用于测试的模拟来电方法
    public func simulateIncomingCall(from caller: String = "测试用户", number: String = "10086") {
        print("[SipManager] 模拟器环境：模拟来电 from: \(caller) - \(number)")
        
        // 在模拟器中，我们直接通知CallManager创建一个来电通知
        self.callState = .incoming
        
        // 通知其他组件有来电
        NotificationCenter.default.post(
            name: NSNotification.Name("SimulatedIncomingCall"),
            object: nil,
            userInfo: ["caller": caller, "number": number]
        )
        
        print("[SipManager] 模拟器环境：已发送模拟来电通知")
    }
    #endif

    // 添加方法以确保当前呼叫状态同步
    private func syncCallState() {
        if let core = core {
            // 检查是否有当前通话
            if currentCall == nil {
                currentCall = core.currentCall
            }
            
            // 更新通话状态
            if let call = currentCall {
                switch call.state {
                case .IncomingReceived:
                    callState = .incoming
                case .OutgoingInit:
                    callState = .outgoingInit
                case .OutgoingRinging:
                    callState = .ringing
                case .Connected:
                    callState = .connected
                case .StreamsRunning:
                    callState = .running
                case .Paused:
                    callState = .paused
                case .End:
                    callState = .ended
                case .Released:
                    callState = .released
                    currentCall = nil
                case .Error:
                    callState = .error
                default:
                    break
                }
            } else {
                callState = .idle
            }
        }
    }

    // 定期调用此方法来确保状态同步
    private func startStateMonitor() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.syncCallState()
        }
    }

    // 设置前置摄像头
    private func setupFrontCamera() {
        // 1. 权限处理
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupFrontCamera()
                    }
                } else {
                    print("用户拒绝了摄像头权限")
                }
            }
            return
        } else if status != .authorized {
            print("摄像头权限未授权")
            return
        }

        // 2. 获取设备列表
        guard let core = core else {
            print("错误：Core 未初始化")
            return
        }
        core.reloadVideoDevices()
        let devices = core.videoDevicesList
        print("可用视频设备：\(devices)")

        // 3. 设备筛选逻辑
        let frontKeywords = ["Front", "front", "前", "Camera 0"]
        let frontCamera = devices.first { device in
            frontKeywords.contains { keyword in device.localizedCaseInsensitiveContains(keyword) }
        } ?? devices.first

        guard let selectedCamera = frontCamera else {
            print("未找到任何摄像头设备")
            return
        }

        // 4. 正确设置摄像头
        do {
            try core.setVideodevice(newValue: selectedCamera)
            print("设置前置摄像头成功：\(selectedCamera)")
        } catch {
            print("设置前置摄像头失败：\(error)")
        }
    }

    func startVideoCall(to remoteUser: String) -> linphonesw.Call? {
        guard let core = self.core else { return nil }
        do {
            let params = try core.createCallParams(call: nil)
        params.videoEnabled = true
            
            // 确保使用前置摄像头
            setupFrontCamera()
            
        guard let address = core.interpretUrl(url: remoteUser) else { return nil }
            let call = try core.inviteAddressWithParams(addr: address, params: params)
            return call
        } catch {
            print("发起视频通话失败: \(error)")
            return nil
        }
    }

    func acceptVideoCall(call: linphonesw.Call) {
        guard let core = self.core else { return }
        do {
            let params = try core.createCallParams(call: call)
            params.videoEnabled = true
            
            // 确保视频激活策略允许自动发起和接受视频
            core.videoActivationPolicy?.automaticallyInitiate = true
            core.videoActivationPolicy?.automaticallyAccept = true
            print("【SIP日志】已在 acceptVideoCall 中设置 videoActivationPolicy 为自动发起和接受。")

            // 确保使用前置摄像头
            setupFrontCamera()
            
            try call.acceptWithParams(params: params)
        } catch {
            print("接听视频通话失败: \(error)")
        }
    }

    func setLocalVideoEnabled(call: linphonesw.Call, enabled: Bool) {
        guard let core = self.core else { return }
        core.videoCaptureEnabled = enabled
        
        if enabled {
            // 如果重新启用视频，确保使用前置摄像头
            setupFrontCamera()
        }
    }

    // 添加一个方便获取当前通话的计算属性
    var currentCallInfo: (call: linphonesw.Call?, state: CallState) {
        return (currentCall, callState)
    }

    // 添加一个用于检查是否有活动通话的计算属性
    var hasActiveCall: Bool {
        return currentCall != nil && callState != .idle && callState != .ended && callState != .released
    }

    // 1. 收到来电
    func onIncomingCall(_ call: linphonesw.Call) {
        print("[SIP日志] 收到来电，主叫: \(call.remoteAddress?.asString() ?? "未知")")
    }

    // 2. 接听来电
    func answerCall(_ call: linphonesw.Call) {
        print("[SIP日志] 正在接听来电")
        // ...原有接听代码...
    }

    // 3. 媒体流初始化
    func onCallStreamsRunning(_ call: linphonesw.Call) {
        print("[SIP日志] 媒体流已启动")
        // 音频流
        if let audioStats = call.audioStats {
            print("[SIP日志] 音频流统计信息: 发送丢包率=\(audioStats.senderLossRate), 接收丢包率=\(audioStats.receiverLossRate), 下行带宽=\(audioStats.downloadBandwidth)kbps, 上行带宽=\(audioStats.uploadBandwidth)kbps")
        } else {
            print("[SIP日志] 无音频流统计信息")
        }
        // 视频流
        if let videoStats = call.videoStats {
            print("[SIP日志] 视频流统计信息: 发送丢包率=\(videoStats.senderLossRate), 接收丢包率=\(videoStats.receiverLossRate), 下行带宽=\(videoStats.downloadBandwidth)kbps, 上行带宽=\(videoStats.uploadBandwidth)kbps")
        } else {
            print("[SIP日志] 无视频流统计信息")
        }
        // 协商的payloadType和codec
        if let params = call.currentParams {
            // 音频
            if let audioPayloadType = params.usedAudioPayloadType {
                print("[SIP日志] 实际音频编码: \(audioPayloadType.mimeType) / \(audioPayloadType.clockRate)")
            }
            // 视频
            if let videoPayloadType = params.usedVideoPayloadType {
                print("[SIP日志] 实际视频编码: \(videoPayloadType.mimeType) / \(videoPayloadType.clockRate)")
            }
        }
    }

    // 4. RTP流推送
    func onRtpStreamStarted(_ call: linphonesw.Call) {
        print("[SIP日志] RTP流已开始推送")
    }

    // 5. 通话挂断
    func onCallEnd(_ call: linphonesw.Call) {
        print("[SIP日志] 通话已挂断，原因: \(call.reason.rawValue)")
    }

    // 6. SIP信令事件
    func onCallStateChanged(_ call: linphonesw.Call, state: linphonesw.Call.State, message: String) {
        print("[SIP日志] 通话状态变化: \(state) - \(message)")
    }

    // MARK: - Video Display Management
    
    /// 设置本地视频预览视图
    func setLocalVideoDisplayView(_ view: UIView) {
        self.localVideoView = view // 强引用持有传入的视图
        guard let core = core else {
            print("[SipManager] setLocalVideoDisplayView: Core is nil. 无法设置本地视频视图。")
            return
        }
        // 将本地视频视图设置给 Linphone Core
        core.nativePreviewWindow = view
        print("[SipManager] 本地视频预览视图已设置。视图实例: \(ObjectIdentifier(view))") // 打印视图实例地址
    }

    /// 设置远端视频显示视图
    func setRemoteVideoDisplayView(_ view: UIView) {
        self.remoteVideoView = view // 强引用持有传入的视图
        guard let core = core else {
            print("[SipManager] setRemoteVideoDisplayView: Core is nil. 无法设置远端视频视图。")
            return
        }
        // 将远端视频视图设置给 Linphone Core
        core.nativeVideoWindow = view
        print("[SipManager] 远端视频显示视图已设置。视图实例: \(ObjectIdentifier(view))") // 打印视图实例地址
    }

    /// 获取本地视频预览视图（用于 SwiftUI 封装） - 仅作辅助，不推荐直接使用返回的视图进行渲染
    func getLocalVideoDisplayView() -> UIView? {
        return localVideoView
    }

    /// 获取远端视频显示视图（用于 SwiftUI 封装） - 仅作辅助，不推荐直接使用返回的视图进行渲染
    func getRemoteVideoDisplayView() -> UIView? {
        return remoteVideoView
    }

    // 添加公共方法来清除本地视频视图引用
    public func clearLocalVideoView() {
        print("【SIP日志】SipManager.clearLocalVideoView() 被调用。")
        self.localVideoView = nil
    }

    // 添加公共方法来清除远端视频视图引用
    public func clearRemoteVideoView() {
        print("【SIP日志】SipManager.clearRemoteVideoView() 被调用。")
        self.remoteVideoView = nil
    }

}

