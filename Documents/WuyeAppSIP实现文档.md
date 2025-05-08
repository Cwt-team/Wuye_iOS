# 物业应用SIP通信实现文档

## 1. 概述

物业应用（WuyeApp）实现了基于SIP协议的VoIP通信功能，用于业主与物业管理处的音视频通话。该功能基于开源的Linphone SDK实现，支持音频通话、视频通话、来电接听、拒接等基础功能。

系统支持Android和iOS两个平台，分别使用了各自平台特性的SIP实现方式，但保持了相同的业务逻辑和功能接口。

## 2. 系统架构

整个SIP通信系统在代码层面采用分层架构设计：

1. **应用层**：用户界面和交互逻辑
2. **业务层**：SIP通信管理，包括账户管理、呼叫控制等
3. **服务层**：底层SIP服务，包括连接维护、协议处理等
4. **SDK层**：Linphone核心功能，包括SIP信令、媒体处理等

### 2.1 核心组件

#### Android平台
- **LinphoneSipManager**：SIP管理类，作为应用层与服务层的桥梁
- **LinphoneService**：后台服务，负责维持SIP连接和处理SIP事件
- **LinphoneManager**：核心管理类，负责初始化和管理Linphone Core
- **LinphoneCallback**：回调接口，用于处理SIP事件通知

#### iOS平台
- **SipManager**：SIP管理类，负责初始化Linphone核心和管理SIP功能
- **SipCallback**：回调接口，用于处理SIP事件通知

## 3. 工作原理

### 3.1 初始化流程

#### Android平台

1. 应用启动时，初始化`LinphoneSipManager`单例
2. `LinphoneSipManager`启动并绑定`LinphoneService`
3. `LinphoneService`创建`LinphoneManager`实例
4. `LinphoneManager`初始化Linphone Core并配置系统参数
5. 根据保存的设置自动注册SIP账户

```java
// LinphoneSipManager初始化
public void init(Context context) {
    Intent intent = new Intent(context, LinphoneService.class);
    boolean bound = context.bindService(intent, connection, Context.BIND_AUTO_CREATE);
}

// LinphoneManager初始化Linphone Core
private LinphoneManager(Context context) {
    factory = Factory.instance();
    factory.setDebugMode(true, "LinphoneSIP");
    core = factory.createCore(null, null, context);
    
    // 配置NAT和网络设置
    configureNatAndNetwork();
    
    // 配置音视频参数
    configureCore();
    configurePayloadTypes();
    
    // 启动Core
    core.start();
}
```

#### iOS平台

1. 应用启动时，初始化`SipManager`单例
2. `SipManager`创建Linphone Factory和Core实例
3. 配置系统参数和音视频编解码器
4. 通过API调用注册SIP账户

```swift
private func initializeLinphone() {
    // 创建Factory实例
    factory = Factory.Instance
    
    // 创建Core实例
    core = try factory?.createCore(configPath: nil, factoryConfigPath: nil, systemContext: nil)
    
    // 设置代理、配置Core和编解码器
    setupCoreDelegate()
    configureCore()
    configureCodecs()
    
    // 启动Core
    try core?.start()
}
```

### 3.2 SIP账户注册

#### Android平台

```java
public void registerAccount(String username, String password, String domain) {
    // 清除现有账户
    for (Account account : core.getAccountList()) {
        core.removeAccount(account);
    }
    
    // 清除现有认证信息
    for (AuthInfo authInfo : core.getAuthInfoList()) {
        core.removeAuthInfo(authInfo);
    }
    
    // 创建认证信息
    AuthInfo authInfo = Factory.instance().createAuthInfo(
            username, username, password, null, null, domain);
    
    // 创建账户参数
    AccountParams accountParams = core.createAccountParams();
    
    // 设置身份地址
    Address identity = Factory.instance().createAddress("sip:" + username + "@" + domain);
    accountParams.setIdentityAddress(identity);
    
    // 设置服务器地址
    accountParams.setServerAddress("sip:" + domain);
    
    // 设置传输协议和超时时间
    accountParams.setTransport(TransportType.Udp);
    accountParams.setExpires(1800);
    
    // 启用注册
    accountParams.setRegisterEnabled(true);
    
    // 创建账户并添加到Core
    Account account = core.createAccount(accountParams);
    core.addAccount(account);
    
    // 设置为默认账户
    core.setDefaultAccount(account);
}
```

#### iOS平台

```swift
func configure(username: String, password: String, domain: String, port: String) {
    // 清除现有账户
    for account in core.accountList {
        core.removeAccount(account: account)
    }
    
    // 清除现有身份验证信息
    for info in core.authInfoList {
        core.removeAuthInfo(info: info)
    }
    
    // 创建身份验证信息
    let authInfo = try factory.createAuthInfo(
        username: username, 
        userid: username,
        passwd: password, 
        ha1: nil, 
        realm: nil, 
        domain: domain
    )
    core.addAuthInfo(info: authInfo)
    
    // 创建代理配置
    let proxyConfig = try core.createProxyConfig()
    
    // 创建身份地址
    let identityAddress = try factory.createAddress(addr: "sip:\(username)@\(domain)")
    try proxyConfig.edit()
    try proxyConfig.setIdentityaddress(newValue: identityAddress)
    
    // 设置代理服务器
    var serverAddress = "sip:\(domain)"
    if !port.isEmpty {
        serverAddress = "sip:\(domain):\(port)"
    }
    try proxyConfig.setServeraddr(newValue: serverAddress)
    
    // 启用注册
    proxyConfig.registerEnabled = true
    
    // 设置过期时间
    proxyConfig.expires = 3600
    
    // 添加代理配置到核心并设为默认
    try core.addProxyConfig(config: proxyConfig)
    core.defaultProxyConfig = proxyConfig
}
```

### 3.3 呼叫管理

#### 呼出通话

```java
// Android端
public void makeCall(String destination, boolean withVideo) {
    try {
        Core core = linphoneManager.getCore();
        
        // 检查是否已注册
        if (core.getDefaultAccount() == null || 
            core.getDefaultAccount().getState() != RegistrationState.Ok) {
            Log.e(TAG, "SIP账户未注册，无法拨打电话");
            return;
        }
        
        // 创建呼叫参数
        CallParams params = core.createCallParams(null);
        
        // 设置媒体加密模式
        params.setMediaEncryption(MediaEncryption.None);
        
        // 设置视频参数
        params.setVideoEnabled(withVideo);
        
        // 设置音频方向
        params.setAudioDirection(MediaDirection.SendRecv);
        
        // 创建地址
        Address remoteAddress = createRemoteAddress(destination);
        
        // 发起呼叫
        core.inviteAddressWithParams(remoteAddress, params);
    } catch (Exception e) {
        Log.e(TAG, "拨打电话失败", e);
    }
}
```

```swift
// iOS端
func call(sipAddress: String) {
    // 创建地址
    let address = try factory.createAddress(addr: "sip:\(sipAddress)")
    
    // 创建呼叫参数
    let params = try core.createCallParams(call: nil)
    
    // 禁用视频
    params.videoEnabled = false
    
    // 设置媒体加密
    params.mediaEncryption = MediaEncryption.None
    
    // 添加自定义头部
    params.addCustomHeader(headerName: "X-FS-Support", headerValue: "update_display,timer")
    params.addCustomHeader(headerName: "X-App-Type", headerValue: "WuyeApp")

    // 发起呼叫
    if let call = core.inviteAddressWithParams(addr: address, params: params) {
        self.currentCall = call
        self.callState = .outgoingInit
    }
}
```

#### 来电接听

```java
// Android端
public void answerCall(boolean withVideo) {
    try {
        Core core = linphoneManager.getCore();
        Call call = core.getCurrentCall();
        
        if (call == null) {
            Log.e(TAG, "没有当前来电，无法接听");
            return;
        }
        
        // 创建呼叫参数
        CallParams params = core.createCallParams(call);
        
        // 设置视频参数
        params.setVideoEnabled(withVideo);
        
        // 设置媒体加密模式
        params.setMediaEncryption(MediaEncryption.None);
        
        // 设置音频方向
        params.setAudioDirection(MediaDirection.SendRecv);
        
        // 接听呼叫
        call.acceptWithParams(params);
    } catch (Exception e) {
        Log.e(TAG, "接听来电失败", e);
    }
}
```

```swift
// iOS端
func acceptCall() {
    // 创建呼叫参数并接受呼叫
    let params = try core.createCallParams(call: call)
    
    // 禁用视频
    params.videoEnabled = false
    
    // 接受呼叫
    try call.acceptWithParams(params: params as CallParams)
}
```

#### 结束通话

```java
// Android端
public void hangupCall() {
    try {
        Core core = linphoneManager.getCore();
        
        // 挂断所有通话
        if (core.getCallsNb() > 0) {
            core.terminateAllCalls();
        }
    } catch (Exception e) {
        Log.e(TAG, "挂断电话失败", e);
    }
}
```

```swift
// iOS端
func terminateCall() {
    // 结束当前呼叫
    try call.terminate()
    callState = .ended
}
```

### 3.4 事件处理

通过回调接口通知应用层SIP事件：

```java
// Android端
private CoreListenerStub listener = new CoreListenerStub() {
    @Override
    public void onCallStateChanged(Core core, Call call, Call.State state, String message) {
        switch (state) {
            case OutgoingInit:
            case OutgoingProgress:
                callback.onCallProgress();
                break;
            case IncomingReceived:
                callback.onIncomingCall(call, call.getRemoteAddress().asStringUriOnly());
                break;
            case StreamsRunning:
                callback.onCallEstablished();
                break;
            case End:
            case Released:
                callback.onCallEnded();
                break;
            case Error:
                callback.onCallFailed(message);
                break;
        }
    }
    
    @Override
    public void onRegistrationStateChanged(Core core, ProxyConfig proxyConfig, 
                                          RegistrationState state, String message) {
        switch (state) {
            case Ok:
                callback.onRegistrationSuccess();
                break;
            case Failed:
                callback.onRegistrationFailed(message);
                break;
        }
    }
};
```

```swift
// iOS端
private func setupCoreDelegate() {
    coreDelegate = CoreDelegateStub(
        onRegistrationStateChanged: { (core: Core, proxyConfig: ProxyConfig, state: RegistrationState, message: String) in
            switch state {
                case .Ok: 
                    self.callback?.onRegistrationSuccess()
                case .Failed:
                    self.callback?.onRegistrationFailed(reason: message)
                default: break
            }
        },
        onCallStateChanged: { (core: Core, call: Call, state: Call.State, message: String) in
            switch state {
                case .OutgoingInit:
                    self.callState = .outgoingInit
                case .Connected:
                    self.callback?.onCallEstablished()
                case .End, .Released:
                    self.callback?.onCallEnded()
                case .Error:
                    self.callback?.onCallFailed(reason: message)
                default: break
            }
        }
    )
}
```

## 4. 平台差异和兼容性

### 4.1 Android平台特性

1. **前台服务**：使用Android前台服务确保SIP连接在后台保持活跃
2. **通知管理**：创建通知渠道和通知以符合Android系统要求
3. **音频路由**：使用Android AudioManager管理音频路由，如扬声器和听筒切换

### 4.2 iOS平台特性

1. **AVFoundation集成**：使用AVAudioSession管理音频会话
2. **权限管理**：处理iOS特有的麦克风和摄像头权限请求
3. **CallKit集成**：可以集成CallKit以提供系统级通话体验

### 4.3 兼容性处理

两个平台采用相同的回调接口设计，确保业务逻辑的一致性：

```java
// Android端
public interface LinphoneCallback {
    void onRegistrationSuccess();
    void onRegistrationFailed(String reason);
    void onIncomingCall(Call call, String caller);
    void onCallProgress();
    void onCallEstablished();
    void onCallEnded();
    void onCallFailed(String reason);
}
```

```swift
// iOS端
protocol SipCallback: AnyObject {
    func onRegistrationSuccess()
    func onRegistrationFailed(reason: String)
    func onIncomingCall(call: Call, caller: String)
    func onCallFailed(reason: String)
    func onCallEstablished()
    func onCallEnded()
}
```

## 5. 核心配置

### 5.1 NAT穿透

为确保在各种网络环境下能够正常工作，系统配置了NAT穿透策略：

```java
// Android端
private void configureNatAndNetwork() {
    org.linphone.core.NatPolicy natPolicy = createNatPolicy();
    natPolicy.setStunEnabled(true);
    natPolicy.setStunServer("stun:stun.l.google.com:19302");
    core.setNatPolicy(natPolicy);
}
```

```swift
// iOS端
private func configureCore() {
    let natPolicy = try core.createNatPolicy()
    natPolicy.stunEnabled = true
    natPolicy.stunServer = "stun:stun.l.google.com:19302"
    core.natPolicy = natPolicy
}
```

### 5.2 编解码器配置

系统配置了音视频编解码器，优先使用PCMA和PCMU等支持度广泛的编解码器：

```java
// Android端
private void configurePayloadTypes() {
    // 设置优先使用的音频编解码器
    for (PayloadType pt : core.getAudioPayloadTypes()) {
        String mimeType = pt.getMimeType();
        int clockRate = pt.getClockRate();
        
        // 启用PCMA和PCMU，禁用其他
        boolean enable = (mimeType.equals("PCMA") && clockRate == 8000) || 
                        (mimeType.equals("PCMU") && clockRate == 8000);
        pt.enable(enable);
        
        // 设置特殊参数
        if (mimeType.equals("PCMA")) {
            pt.setRecvFmtp("annexb=no");
        }
    }
}
```

```swift
// iOS端
private func configureCodecs() {
    for payload in core.audioPayloadTypes {
        let mimeType = payload.mimeType
        let rate = payload.clockRate

        // 只启用PCMA和PCMU编解码器
        let enable = (mimeType == "PCMA" && rate == 8000) || (mimeType == "PCMU" && rate == 8000)
        try payload.enable(enabled: enable)
        
        // 为PCMA设置特殊参数
        if mimeType == "PCMA" {
            payload.recvFmtp = "annexb=no"
        }
    }
}
```

## 6. 最佳实践与优化

1. **单例模式**：核心管理类采用单例模式，确保全局唯一实例
2. **资源管理**：及时释放不需要的资源，防止内存泄漏
3. **错误处理**：完善的异常捕获和错误处理机制
4. **日志记录**：详细的日志记录，便于问题排查
5. **线程安全**：关键操作保证线程安全，避免并发问题
6. **网络检测**：检测网络状态变化，及时更新连接状态

## 7. 拓展功能

系统支持但未在基础版本中实现的功能：

1. **视频通话**：支持通过参数配置启用视频通话
2. **多方通话**：支持电话会议功能
3. **呼叫转移**：支持通话转接功能
4. **DTMF发送**：支持在通话过程中发送DTMF信号
5. **加密通信**：支持设置媒体加密模式，如SRTP

## 8. 结论

物业应用的SIP通信系统利用Linphone SDK构建了完整的VoIP通信解决方案，支持Android和iOS两个平台。系统架构清晰，接口统一，功能完善，为业主与物业之间的即时通讯提供了可靠的技术支持。

通过对NAT穿透、编解码器和音频路由的优化，系统能够适应各种网络环境，提供良好的通话质量。同时，系统的可扩展性也为未来功能的扩展提供了基础。 