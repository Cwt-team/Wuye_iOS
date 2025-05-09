import SwiftUI

/// 偏好设置视图
struct PreferencesView: View {
    // 外观设置
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @AppStorage("accentColor") private var accentColorString = "blue"
    
    // 通用设置
    @AppStorage("useFaceID") private var useFaceID = true
    @AppStorage("autoLock") private var autoLock = true
    @AppStorage("autoLockTime") private var autoLockTime = 5
    @AppStorage("showStatusBar") private var showStatusBar = true
    
    // 隐私设置
    @AppStorage("trackLocation") private var trackLocation = true
    @AppStorage("shareAnalytics") private var shareAnalytics = true
    
    // 可选的强调色
    private let accentColors = [
        "blue": Color.blue,
        "purple": Color.purple,
        "pink": Color.pink,
        "red": Color.red,
        "orange": Color.orange,
        "green": Color.green
    ]
    
    // 自动锁定时间选项
    private let lockTimeOptions = [1, 3, 5, 10, 15]
    
    var body: some View {
        Form {
            // 外观设置
            Section(header: Text("外观")) {
                Toggle("使用系统主题", isOn: $useSystemTheme)
                
                if !useSystemTheme {
                    Toggle("深色模式", isOn: $isDarkMode)
                }
                
                // 强调色选择
                HStack {
                    Text("强调色")
                    
                    Spacer()
                    
                    ForEach(Array(accentColors.keys.sorted()), id: \.self) { key in
                        Circle()
                            .fill(accentColors[key]!)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray, lineWidth: accentColorString == key ? 2 : 0)
                            )
                            .onTapGesture {
                                accentColorString = key
                            }
                            .padding(.leading, 4)
                    }
                }
            }
            
            // 通用设置
            Section(header: Text("通用")) {
                Toggle("使用Face ID/Touch ID登录", isOn: $useFaceID)
                
                Toggle("自动锁定应用", isOn: $autoLock)
                
                if autoLock {
                    Picker("自动锁定时间", selection: $autoLockTime) {
                        ForEach(lockTimeOptions, id: \.self) { time in
                            Text("\(time) 分钟").tag(time)
                        }
                    }
                }
                
                Toggle("显示状态栏", isOn: $showStatusBar)
            }
            
            // 隐私设置
            Section(header: Text("隐私")) {
                Toggle("位置追踪", isOn: $trackLocation)
                    .onChange(of: trackLocation) { newValue in
                        if newValue {
                            // 请求位置权限
                            requestLocationPermission()
                        }
                    }
                
                Toggle("共享使用分析", isOn: $shareAnalytics)
            }
            
            // 联系信息
            Section(header: Text("其他")) {
                NavigationLink(destination: Text("关于我们页面")) {
                    Text("关于我们")
                }
                
                NavigationLink(destination: Text("隐私政策页面")) {
                    Text("隐私政策")
                }
                
                NavigationLink(destination: Text("用户协议页面")) {
                    Text("用户协议")
                }
            }
        }
        .navigationTitle("偏好设置")
        .onAppear(perform: checkPermissions)
    }
    
    // 检查权限
    private func checkPermissions() {
        // 检查是否有Face ID可用
        checkBiometricAuthAvailability()
    }
    
    // 检查生物识别认证可用性
    private func checkBiometricAuthAvailability() {
        // 这里应该实现生物识别认证检查
        // 如果不可用，应设置useFaceID = false
    }
    
    // 请求位置权限
    private func requestLocationPermission() {
        // 这里应该实现位置权限请求
        // 如果用户拒绝，应设置trackLocation = false
    }
}

// 预览
struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PreferencesView()
        }
    }
} 