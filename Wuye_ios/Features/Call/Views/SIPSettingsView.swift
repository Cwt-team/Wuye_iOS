import SwiftUI
import linphonesw

/// SIP设置界面
struct SIPSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var callManager: CallManager
    
    // SIP配置
    @State private var sipServer: String = ""
    @State private var sipPort: String = "5060"
    @State private var sipUsername: String = ""
    @State private var sipPassword: String = ""
    @State private var transport: String = "UDP"
    
    // 状态
    @State private var isRegistered: Bool = false
    @State private var registrationStatus: String = "未注册"
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isShowingTestCallAlert: Bool = false
    @State private var isRegistering: Bool = false
    
    // 传输协议选项
    private let transportOptions = ["UDP", "TCP", "TLS"]
    
    var body: some View {
        NavigationView {
            Form {
                // SIP服务器配置
                Section(header: Text("SIP服务器配置")) {
                    TextField("服务器地址", text: $sipServer)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    TextField("端口 (默认: 5060)", text: $sipPort)
                        .keyboardType(.numberPad)
                    
                    Picker("传输协议", selection: $transport) {
                        ForEach(transportOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                
                // 账户配置
                Section(header: Text("SIP账户")) {
                    TextField("用户名", text: $sipUsername)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("密码", text: $sipPassword)
                }
                
                // 状态显示
                Section(header: Text("注册状态")) {
                    HStack {
                        Text(registrationStatus)
                        
                        Spacer()
                        
                        // 注册状态指示灯
                        Circle()
                            .frame(width: 12, height: 12)
                            .foregroundColor(isRegistered ? .green : .red)
                    }
                    
                    if isRegistering {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }
                    }
                }
                
                // 操作按钮
                Section {
                    Button(action: saveAndRegister) {
                        HStack {
                            Spacer()
                            Text("保存并注册")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(sipServer.isEmpty || sipUsername.isEmpty || sipPassword.isEmpty || isRegistering)
                    
                    Button(action: testSipCall) {
                        HStack {
                            Spacer()
                            Text("测试呼叫")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(!isRegistered || isRegistering)
                }
                
                // 调试信息
                Section(header: Text("版本信息")) {
                    Text("Linphone SDK 版本: \(SipManager.shared.getVersionInfo())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("SIP设置")
            .navigationBarItems(
                trailing: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear(perform: loadSettings)
            .onChange(of: isRegistered) { newValue in
                updateStatus()
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("通知"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
            .alert(isPresented: $isShowingTestCallAlert) {
                Alert(
                    title: Text("测试呼叫"),
                    message: Text("请输入要呼叫的SIP地址:"),
                    primaryButton: .default(Text("呼叫"), action: {
                        performTestCall()
                    }),
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }
    
    // 加载已保存的SIP设置
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        sipServer = defaults.string(forKey: "sipServer") ?? ""
        sipPort = defaults.string(forKey: "sipPort") ?? "5060"
        sipUsername = defaults.string(forKey: "sipUsername") ?? ""
        sipPassword = defaults.string(forKey: "sipPassword") ?? ""
        transport = defaults.string(forKey: "sipTransport") ?? "UDP"
        
        // 检查当前注册状态
        checkRegistrationStatus()
    }
    
    // 保存设置并注册
    private func saveAndRegister() {
        // 保存设置到UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(sipServer, forKey: "sipServer")
        defaults.set(sipPort, forKey: "sipPort")
        defaults.set(sipUsername, forKey: "sipUsername")
        defaults.set(sipPassword, forKey: "sipPassword")
        defaults.set(transport, forKey: "sipTransport")
        
        // 显示注册中状态
        isRegistering = true
        registrationStatus = "正在注册..."
        
        // 配置SIP账户并注册
        DispatchQueue.global(qos: .userInitiated).async {
            // 配置SIP账户
            SipManager.shared.configureSipAccount(
                username: sipUsername,
                password: sipPassword,
                domain: sipServer,
                port: sipPort,
                transport: transport
            )
            
            // 配置注册回调
            setupCallbacks()
            
            // 刷新注册
            SipManager.shared.refreshRegistrations()
            
            // 延迟5秒后检查注册状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                checkRegistrationStatus()
                isRegistering = false
            }
        }
    }
    
    // 设置SIP回调
    private func setupCallbacks() {
        SipManager.shared.setSipCallback(SipCallback())
    }
    
    // 检查注册状态
    private func checkRegistrationStatus() {
        let status = SipManager.shared.registrationState
        
        DispatchQueue.main.async {
            switch status {
            case .none:
                self.isRegistered = false
                self.registrationStatus = "未注册"
            case .progress:
                self.isRegistered = false
                self.registrationStatus = "注册中..."
            case .ok:
                self.isRegistered = true
                self.registrationStatus = "已注册"
            case .cleared:
                self.isRegistered = false
                self.registrationStatus = "已清除"
            case .failed:
                self.isRegistered = false
                self.registrationStatus = "注册失败"
            @unknown default:
                self.isRegistered = false
                self.registrationStatus = "未知状态"
            }
        }
    }
    
    // 更新状态显示
    private func updateStatus() {
        // 根据注册状态显示提示
        if isRegistered {
            alertMessage = "SIP账户注册成功！"
            showingAlert = true
        }
    }
    
    // 测试SIP呼叫
    private func testSipCall() {
        isShowingTestCallAlert = true
    }
    
    // 执行测试呼叫
    private func performTestCall() {
        // 呼叫SIP测试服务
        let testNumber = "sip:echo@" + sipServer
        SipManager.shared.call(recipient: testNumber)
        
        // 显示呼叫提示
        alertMessage = "正在测试呼叫: \(testNumber)"
        showingAlert = true
    }
}

// 用于SIP回调的类
class SipCallback: SipManagerCallback {
    // 移除非协议方法
    // func onRegistrationStateChanged(state: RegState, message: String) {
    //    print("SIP注册状态变更: \(state) - \(message)")
    // }
    
    // func onCallStateChanged(state: linphonesw.Call.State, message: String) {
    //    print("SIP呼叫状态变更: \(state) - \(message)")
    // }
    
    func onIncomingCall(call: linphonesw.Call, caller: String) {
        print("SIP来电: \(caller)")
    }
    
    func onCallEstablished() {
        print("SIP通话已建立")
    }
    
    func onCallEnded() {
        print("SIP通话已结束")
    }
    
    func onRegistrationSuccess() {
        print("SIP注册成功")
    }
    
    func onRegistrationFailed(reason: String) {
        print("SIP注册失败: \(reason)")
    }
    
    func onCallFailed(reason: String) {
        print("SIP呼叫失败: \(reason)")
    }
    
    func onSipRegistrationStateChanged(isSuccess: Bool, message: String) {
        print("SIP注册状态: \(isSuccess ? "成功" : "失败") - \(message)")
    }
    
    func onCallQualityChanged(quality: Float, message: String) {
        print("SIP通话质量变更: \(quality) - \(message)")
    }
}

// 预览
struct SIPSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SIPSettingsView()
            .environmentObject(CallManager())
    }
} 