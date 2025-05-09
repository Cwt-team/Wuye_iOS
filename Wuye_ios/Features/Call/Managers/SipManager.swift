//
//  SipManager.swift
//
//  Created to manage SIP functionalities using linphonesw on iOS
//

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
    
    private func handleCallStateChanged(call: linphonesw.Call?, state: linphonesw.Call.State, message: String) {
        // 在处理来电前记录更多日志
        guard let call = call else {
            print("[SIP-错误] 收到空的呼叫对象")
            return
        }
        
        print("呼叫状态变更: \(state) (\(message))")
        
        switch state {
        case .IncomingReceived, .PushIncomingReceived:
            print("[SIP-详细] 收到来电状态变更，准备处理: 状态=\(state.rawValue), 远程地址=\(call.remoteAddressAsString ?? "未知")")
            callState = .incoming
            currentCall = call
            preventSleepDuringCall(true)
            
            // 获取来电者信息
            let caller = call.remoteAddressAsString ?? "未知来电"
            
            // 添加更多诊断信息
            print("[SIP-详细] 回调对象存在检查: \(callback != nil)")
            
            // 安全地通知UI层显示来电界面
            DispatchQueue.main.async { [weak self] in
                self?.callback?.onIncomingCall(call: call, caller: caller)
                print("[SIP-详细] 已通知回调处理来电: 回调对象存在=\(self?.callback != nil)")
            }
            
        case .OutgoingInit:
            callState = .outgoingInit
            currentCall = call
            preventSleepDuringCall(true)
            
        case .OutgoingRinging:
            callState = .ringing
            
        case .Connected:
            callState = .connected
            callback?.onCallEstablished()
            
        case .StreamsRunning:
            callState = .running
            
        case .Paused, .PausedByRemote:
            callState = .paused
            
        case .Error:
            callState = .error
            callback?.onCallFailed(reason: message)
            preventSleepDuringCall(false)
            
        case .End, .Released:
            callState = state == .End ? .ended : .released
            preventSleepDuringCall(false)
            
            if state == .End {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.callback?.onCallEnded()
                    self.currentCall = nil
                }
            }
            
        default:
            break
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
        // 1. 确保AVAudioSession正确配置
        try configureAudioSession()
        
        // 2. 重新加载Linphone音频设备
        prepareAudioDevices()
        
        // 3. 确保麦克风已启用
        if let core = core, !core.micEnabled {
            core.micEnabled = true
        }
    }

    // 配置音频会话
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        print("[SIP] 开始配置音频会话...")
        
        // 先停止任何正在进行的会话
        do {
        try session.setActive(false, options: .notifyOthersOnDeactivation)
            print("[SIP] 已停止现有音频会话")
        } catch {
            print("[SIP] 停止现有音频会话时出错: \(error)，将继续尝试配置新会话")
        }
        
        #if targetEnvironment(simulator)
        // 模拟器环境使用更简单的配置
        do {
            // 先使用最基础的配置
            try session.setCategory(.ambient)
            try session.setMode(.default)
            print("[SIP] 已为模拟器环境设置简单音频配置")
            
            // 尝试激活会话
            try session.setActive(true)
            print("[SIP] 模拟器环境音频会话已激活")
            
            // 获取会话状态信息
            print("[SIP] 音频会话信息: 采样率=\(session.sampleRate)Hz, 缓冲帧=\(session.inputLatency)")
            return  // 成功配置后直接返回
        } catch {
            print("[SIP] 模拟器简单音频配置失败: \(error)，尝试其他方法")
            // 不抛出错误，继续尝试下面的配置
        }
        #endif
        
        // 使用兼容性更好的音频会话参数
        do {
            #if targetEnvironment(simulator)
            // 第二次尝试模拟器环境配置
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            print("[SIP] 已为模拟器环境设置备用音频配置")
            #else
            // 真机使用标准配置
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            print("[SIP] 已为真机环境设置标准音频配置")
            #endif
        } catch {
            print("[SIP] 设置音频会话类别和模式失败: \(error)，尝试使用最简单配置")
            
            // 尝试最简单的配置
            try session.setCategory(.playAndRecord)
            print("[SIP] 已应用最简单音频配置")
        }
        
        // 激活会话
        do {
        try session.setActive(true, options: [.notifyOthersOnDeactivation])
            print("[SIP] 音频会话已配置并激活: 模式=\(session.mode.rawValue), 采样率=\(session.sampleRate)Hz")
        } catch let error as NSError {
            // 特别处理错误-66637 (kAudioUnitErr_CannotDoInCurrentContext)
            if error.code == -66637 {
                print("[SIP] 检测到特定错误-66637，正在尝试延迟重试")
                
                // 多次尝试激活
                var attemptCount = 0
                var lastError: Error? = error
                
                while attemptCount < 3 {
                    Thread.sleep(forTimeInterval: 0.7)  // 增加等待时间
                    attemptCount += 1
                    
                    do {
                        try session.setActive(true, options: [.notifyOthersOnDeactivation])
                        print("[SIP] 第\(attemptCount)次重试激活音频会话成功")
                        return  // 成功激活则返回
                    } catch let retryError {
                        lastError = retryError
                        print("[SIP] 第\(attemptCount)次重试失败: \(retryError)")
                    }
                }
                
                #if targetEnvironment(simulator)
                // 在模拟器中即使失败也继续执行
                print("[SIP] 模拟器环境中忽略音频会话激活错误，继续执行")
                #else
                // 在真机上抛出最后一个错误
                print("[SIP] 多次尝试后仍无法激活音频会话")
                if let lastError = lastError {
                    throw lastError
                }
                #endif
            } else {
                print("[SIP] 激活音频会话失败，错误: \(error)")
                
                #if targetEnvironment(simulator)
                // 在模拟器环境中忽略错误
                print("[SIP] 模拟器环境中忽略音频会话错误，继续执行")
                #else
                throw error
                #endif
            }
        }
    }
    
    // 准备音频设备
    private func prepareAudioDevices() {
        guard let core = core else { 
            print("[SIP] 无法准备音频设备：核心未初始化")
            return 
        }
        
        print("[SIP] 开始准备音频设备...")
        
        #if targetEnvironment(simulator)
        // 针对模拟器的额外设置
        core.audioJittcomp = 200      // 增加音频抖动补偿
        core.echoCancellationEnabled = false  // 模拟器中禁用回声消除
        linphone_core_set_use_rfc2833_for_dtmf(core.getCobject, 1)  // 使用带外DTMF
        
        // 设置音频特性
        let config = core.config
        linphone_config_set_int(config?.getCobject, "sound", "disable_audio_unit_start_failure", 1)
        print("[SIP] 已为模拟器环境设置特殊音频参数")
        #endif
        
        // 首先重新加载所有音频设备
        core.reloadSoundDevices()
        print("[SIP] 已重新加载音频设备")
        
        // 打印可用设备
        var captureDevices: [String] = []
        var playbackDevices: [String] = []
        
        for device in core.audioDevices {
            if device.hasCapability(capability: AudioDeviceCapabilities.CapabilityRecord) {
                captureDevices.append(device.id)
            }
            if device.hasCapability(capability: AudioDeviceCapabilities.CapabilityPlay) {
                playbackDevices.append(device.id)
            }
        }
        
        print("[SIP] Linphone音频设备:")
        print("[SIP] - 捕获设备: \(captureDevices.joined(separator: ", "))")
        print("[SIP] - 播放设备: \(playbackDevices.joined(separator: ", "))")
        
        #if targetEnvironment(simulator)
        // 在模拟器环境中，可能需要特殊处理
        if captureDevices.isEmpty {
            print("[SIP] 在模拟器中检测不到捕获设备，这是正常的")
            
            // 模拟器环境中设置一些虚拟设备
            let config = core.config
            linphone_config_set_string(config?.getCobject, "sound", "capture_dev", "")
            linphone_config_set_string(config?.getCobject, "sound", "playback_dev", "")
            
            // 禁用音频错误检查
            linphone_config_set_int(config?.getCobject, "sound", "disable_error_check", 1)
        }
        
        // 设置更保守的音频参数
        core.useFiles = true  // 在模拟器中使用文件而不是真实音频设备
        print("[SIP] 在模拟器环境中已启用文件模式替代真实音频设备")
        
        // 禁用可能导致问题的功能
        core.videoCaptureEnabled = false
        core.videoDisplayEnabled = false
        core.videoPreviewEnabled = false
        
        // 降低采样率以减少处理负担
        linphone_config_set_int(config?.getCobject, "sound", "playback_ptime", 40)  // 增加播放包时间
        linphone_config_set_int(config?.getCobject, "sound", "forced_sample_rate", 8000)  // 使用较低采样率
        #else
        // 在真机上，如果没有检测到捕获设备，可能需要额外处理
        if captureDevices.isEmpty {
            print("[SIP] 警告：未检测到任何捕获设备，请检查麦克风权限和硬件")
        }
        
        // 配置音频处理参数
        core.echoCancellationEnabled = true
        core.adaptiveRateControlEnabled = true
        #endif
        
        print("[SIP] 音频设备准备完成")
    }
    
    // 接受呼叫
    func acceptCall() {
        guard let call = self.currentCall else {
            print("[SIP] 没有活动呼叫可接受")
            return
        }
        
        do {
            // 先配置音频
            try prepareAudioForCall()
            
            // 创建通话参数
            if let params = try call.currentParams?.copy() {
                print("[SIP] 正在接受呼叫，参数配置: 音频=\(params.audioEnabled), 视频=\(params.videoEnabled)")
                
                // 直接使用C API调用，确保getCobject返回的不是nil
                if let callPtr = call.getCobject, let paramsPtr = params.getCobject {
                    let result = linphone_call_accept_with_params(callPtr, paramsPtr)
                    if result == 0 {
                        print("[SIP] 呼叫接受命令已发送")
                    } else {
                        print("[SIP] 呼叫接受失败，错误码：\(result)")
                        throw LinphoneError.exception(result: "acceptWithParams returned value \(result)")
                    }
                } else {
                    print("[SIP] 呼叫接受失败：内部对象为空")
                    throw LinphoneError.exception(result: "Null pointer in call or params")
                }
            } else {
                // 如果没有当前参数，使用简单的accept
                try call.accept()
                print("[SIP] 使用简单方式接受呼叫成功")
            }
        } catch {
            print("[SIP] 接受呼叫错误: \(error)")
            // 尝试回退到简单接听
            do {
                try call.accept()
                print("[SIP] 使用简单方式接受呼叫成功")
            } catch {
                print("[SIP] 简单接受呼叫也失败: \(error)")
            }
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

    func setSipCallback(_ delegate: SipManagerCallback) {
        print("[SipManager] 设置回调处理器: \(delegate)")
        self.callback = delegate
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
}

