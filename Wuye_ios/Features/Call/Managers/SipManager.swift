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
    private var currentCall: linphonesw.Call?
    private var callback: SipManagerCallback?
    private var coreDelegate: CoreDelegateStub?
    private var CoreTimer = Timer()

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
            core = try factory?.createCore(configPath: nil, factoryConfigPath: nil, systemContext: nil)
            print("Linphone Core创建成功")
            
            // 设置代理
            setupCoreDelegate()
            
            // 配置Core
            configureCore()
            
            // 配置编解码器
            configureCodecs()
            
            // 启动Core
            try core?.start()
            print("Linphone Core启动成功")
            
            // 启动Core迭代计时器
            startCoreTimer()
        } catch {
            print("Initialization error: \(error)")
        }
    }
    
    private func setupCoreDelegate() {
        guard let core = core else { return }
        
        coreDelegate = CoreDelegateStub(
            onRegistrationStateChanged: { (core: Core, proxyConfig: ProxyConfig, state: RegistrationState, message: String) in
                // 将RegistrationState转换为我们自定义的RegState
                let regState: RegState
                switch state {
                case .None: regState = .none
                case .Progress: regState = .progress
                case .Ok: regState = .ok
                case .Failed: regState = .failed
                case .Cleared: regState = .cleared
                default: regState = .none
                }
                self.handleRegistrationStateChanged(state: regState, message: message)
            },
            onCallStateChanged: { (core: Core, call: linphonesw.Call, state: linphonesw.Call.State, message: String) in
                self.handleCallStateChanged(call: call, state: state, message: message)
            }
        )
        
        core.addDelegate(delegate: coreDelegate!)
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
        
        // 禁用所有编解码器
        for payload in core.audioPayloadTypes {
            payload.enable(enabled: false)
        }
        
        // 只启用最广泛支持的编解码器，按优先级排序
        let enabledCodecs = ["PCMU", "PCMA", "G729"]
        var enabledCount = 0
        
        for codec in enabledCodecs {
            for payload in core.audioPayloadTypes {
                if payload.mimeType.lowercased() == codec.lowercased() {
                    payload.enable(enabled: true)
                    print("已启用编解码器: \(payload.mimeType) (\(payload.clockRate)Hz)")
                    enabledCount += 1
                    break
                }
            }
        }
        
        print("音频编解码器配置完成: 已启用 \(enabledCount) 个编解码器")
    }
    
    // MARK: - Core Delegate Handlers
    
    private func handleCallStateChanged(call: linphonesw.Call, state: linphonesw.Call.State, message: String) {
        print("[SipManager] 通话状态改变: \(state), 消息: \(message)")
        
        DispatchQueue.main.async {
            switch state {
            case .IncomingReceived:
                self.currentCall = call
                self.callState = .incoming
                if let caller = call.remoteAddress?.username {
                    // 通知回调
                    self.callback?.onIncomingCall(call: call, caller: caller)
                    
                    // 不在这里显示来电界面，而是由 CallManager 负责
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
            case .Paused:
                self.callState = .paused
            case .End:
                self.callState = .ended
                self.callback?.onCallEnded()
            case .Error:
                self.callState = .error
                self.callback?.onCallFailed(reason: message)
            default:
                break
            }
        }
    }
    
    private func handleRegistrationStateChanged(state: RegState, message: String) {
        print("注册状态变更: \(state) (\(message))")
        
        DispatchQueue.main.async {
            self.registrationState = state
            
            switch state {
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
                
            default:
                print("[SIP] 未知注册状态")
                break
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

    func call(recipient: String) {
        guard isRegistered else {
            print("SIP未注册，无法发起呼叫")
            return
        }
        
        // 如果存在当前通话，先终止它
        if let call = currentCall {
            let currentState = call.state
            if currentState != linphonesw.Call.State.End && currentState != linphonesw.Call.State.Released {
                print("SIP日志: 正在结束当前通话...")
                do {
                    try call.terminate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.currentCall = nil
                        self?.makeNewCall(recipient: recipient)
                    }
                } catch {
                    print("SIP日志: 结束当前通话失败: \(error)")
                    currentCall = nil
                    callState = .idle
                    makeNewCall(recipient: recipient)
                }
                return
            }
        }
        
        makeNewCall(recipient: recipient)
    }
    
    private func makeNewCall(recipient: String) {
        do {
            print("SIP日志: 正在发起呼叫: \(recipient)")
            
            // 构建目标地址
            let targetAddress: String
            if recipient.hasPrefix("sip:") {
                targetAddress = recipient
            } else if recipient.contains("@") {
                targetAddress = "sip:\(recipient)"
            } else {
                let domain = UserDefaults.standard.string(forKey: "sipDomain") ?? "116.198.199.38"
                let port = UserDefaults.standard.string(forKey: "sipPort") ?? "5060"
                targetAddress = "sip:\(recipient)@\(domain):\(port)"
            }
            
            print("SIP日志: 呼叫地址为: \(targetAddress)")
            
            requestMicrophoneAndCameraPermissions { [weak self] granted in
                guard let self = self, granted else {
                    print("SIP日志: 麦克风权限被拒绝，无法进行通话")
                    return
                }
                
                DispatchQueue.main.async {
                    do {
                        // 优化音频准备和连接
                        self.preventSleepDuringCall(true)
                        
                        // 首先准备音频会话和设备
                        try self.prepareAudioForCall()
                        
                        // 创建目标地址
                        guard let factory = self.factory else {
                            print("SIP日志: Factory未初始化")
                            return
                        }
                        
                        let address = try factory.createAddress(addr: targetAddress)
                        
                        // 创建呼叫参数
                        guard let core = self.core else {
                            print("SIP日志: Core未初始化")
                            return
                        }
                        
                        let params = try core.createCallParams(call: nil)
                        
                        // 设置媒体参数 - 确保正确设置
                        params.audioEnabled = true
                        params.videoEnabled = false
                        params.mediaEncryption = MediaEncryption.None
                        
                        // 尝试发起呼叫
                        let call = try core.inviteAddressWithParams(addr: address, params: params)
                        self.currentCall = call
                        self.callState = .outgoingInit
                        
                        print("SIP日志: 呼叫已发起，等待对方接听")
                    } catch {
                        print("SIP日志: 发起呼叫失败: \(error)")
                        self.preventSleepDuringCall(false)
                    }
                }
            }
        } catch {
            print("SIP日志: 创建呼叫失败: \(error)")
        }
    }
    
    // 防止通话期间设备休眠
    private func preventSleepDuringCall(_ prevent: Bool) {
        UIApplication.shared.isIdleTimerDisabled = prevent
    }
    
    // MARK: - Audio Management

    // 对外提供的音频准备方法
    func prepareAudioForCall() throws {
        print("[SipManager] 准备音频设备")
        
        #if targetEnvironment(simulator)
        // 在模拟器中跳过音频设备初始化
        print("[SipManager] 在模拟器中跳过音频配置")
        return
        #else
        // 真机上的音频配置代码
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            print("[SipManager] 音频会话已配置")
        } catch {
            print("[SipManager] 配置音频会话时出错: \(error)")
            throw error
        }
        
        // 确保Linphone音频设备配置正确
        if let core = self.core {
            // 日志当前可用的音频设备
            print("[SipManager] 当前可用音频设备: \(core.audioDevices.map { $0.deviceName })")
            
            // 设置音频设备
            for device in core.audioDevices {
                if device.type == .Speaker {
                    print("[SipManager] 使用扬声器作为输出设备")
                    core.outputAudioDevice = device
                    break
                }
            }
            
            // 尝试找到并使用合适的音频输入设备
            for device in core.audioDevices {
                if device.type == .Microphone {
                    print("[SipManager] 使用麦克风作为输入设备")
                    core.inputAudioDevice = device
                    break
                }
            }
        }
        #endif
    }

    // MARK: - Call Management

    func acceptCall() {
        print("[SipManager] 尝试接听电话")
        
        do {
            // 检查当前通话状态
            if callState != .incoming {
                print("[SipManager] 错误: 尝试接听不是来电状态的通话，当前状态: \(callState)")
                return
            }
            
            // 如果 currentCall 为空，但状态是 incoming，尝试从 core 获取当前通话
            if currentCall == nil, let core = self.core {
                if let call = core.currentCall {
                    print("[SipManager] 找到当前通话，正在尝试接听")
                    currentCall = call
                } else if let call = core.calls.first {
                    print("[SipManager] 从通话列表中获取第一个通话，正在尝试接听")
                    currentCall = call
                } else {
                    print("[SipManager] 错误: 尝试接听电话，但没有找到任何通话")
                    return
                }
            }
            
            guard let currentCall = self.currentCall else {
                print("[SipManager] 错误: 尝试接听电话，但没有当前通话")
                return
            }
            
            // 确保音频设备准备就绪
            try prepareAudioForCall()
            
            print("[SipManager] 接听电话: \(currentCall)")
            try currentCall.accept()
            print("[SipManager] 电话已接听")
            
        } catch {
            print("[SipManager] 接听电话时出错: \(error)")
            // 通知调用者出现了错误
            callback?.onCallFailed(reason: "接听电话时出错: \(error)")
        }
    }

    func terminateCall() {
        guard let call = currentCall else {
            print("[SIP] 终止呼叫: 没有活动呼叫")
            return
        }
        
        print("[SIP] 正在终止通话，当前状态: \(call.state.rawValue)")
        
        do {
            // 结束当前呼叫
            try call.terminate()
            callState = .ended
            print("[SIP] 通话终止命令已发送，状态已更新为ended")
            
            // 释放相关资源
            preventSleepDuringCall(false)
            
            // 延迟更新状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.callState = .released
                self.callback?.onCallEnded()
                self.currentCall = nil
                print("[SIP] 通话已完全释放")
                
                // 释放音频会话
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    print("[SIP] 音频会话已释放")
                } catch {
                    print("[SIP] 释放音频会话错误: \(error)")
                }
            }
        } catch {
            print("[SIP] 终止呼叫错误: \(error)")
            // 如果正常终止失败，强制清理
            self.callState = .released
            self.currentCall = nil
            try? AVAudioSession.sharedInstance().setActive(false)
            print("[SIP] 强制清理通话状态完成")
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
        if let version = linphone_core_get_version() {
            return "Linphone SDK \(String(cString: version))"
        }
        return "未知版本"
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
}

