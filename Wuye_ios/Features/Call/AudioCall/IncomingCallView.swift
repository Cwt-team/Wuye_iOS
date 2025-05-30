import SwiftUI
import AVFoundation
import AudioToolbox
import linphonesw

struct IncomingCallView: View {
    @ObservedObject private var sipManager = SipManager.shared
    @State private var showCallView = false
    @State private var callAccepted = false
    @State private var isRinging = true
    @State private var audioPlayer: AVAudioPlayer?
    
    // 使用单例
    private let callManager = CallManager.shared
    
    @Environment(\.presentationMode) var presentationMode
    
    let call: linphonesw.Call
    let callerName: String
    let callerNumber: String
    
    init(call: linphonesw.Call, callerName: String, callerNumber: String) {
        self.call = call
        self.callerName = callerName
        self.callerNumber = callerNumber
    }
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Spacer()
                
                // 来电信息
                VStack(spacing: 15) {
                    Text("来电")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(callerName)
                        .font(.system(size: 35, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(callerNumber)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding()
                
                Spacer()
                
                // 接听和拒绝按钮
                HStack(spacing: 70) {
                    // 拒绝按钮
                    Button(action: {
                        stopRinging()
                        sipManager.terminateCall()
                        callManager.clearIncomingCall()
                    }) {
                        VStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "phone.down.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                )
                            
                            Text("拒绝")
                                .font(.callout)
                                .foregroundColor(.white)
                                .padding(.top, 8)
                        }
                    }
                    
                    // 接听按钮
                    Button(action: {
                        stopRinging()
                        callAccepted = true
                        
                        // 在主线程上执行，并添加延迟以确保音频设备准备就绪
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // 尝试接听电话
                            sipManager.acceptCall()
                            
                            // 短暂延迟后再显示通话界面，以确保通话已建立
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showCallView = true
                            }
                        }
                    }) {
                        VStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                )
                            
                            Text("接听")
                                .font(.callout)
                                .foregroundColor(.white)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
        .onAppear {
            print("[IncomingCallView] 视图出现")
            startRinging()
        }
        .onDisappear {
            print("[IncomingCallView] 视图消失")
            stopRinging()
            
            // 如果没有接听，且不是通过CallView离开的，则拒绝来电
            if !callAccepted && !showCallView {
                sipManager.terminateCall()
                CallManager.shared.clearIncomingCall()
            }
        }
        .fullScreenCover(isPresented: $showCallView) {
            CallView(callerName: callerName, callerNumber: callerNumber, isIncoming: true)
        }
    }
    
    private func setupRingtone() {
        // 尝试获取默认铃声
        do {
            print("[IncomingCallView] 开始设置铃声...")
            
            // 使用系统声音作为备选方案
            let useFallbackSound = {
                print("[IncomingCallView] 使用系统提示音作为铃声")
                AudioServicesPlayAlertSound(SystemSoundID(1007)) // 使用系统铃声ID
                
                // 创建全局变量跟踪铃声状态
                let isPlaying = self.isRinging // 捕获当前值
                Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
                    if isPlaying {
                        AudioServicesPlayAlertSound(SystemSoundID(1007))
                    } else {
                        timer.invalidate()
                    }
                }
            }
            
            // 尝试多种铃声文件
            let ringtonePaths = [
                Bundle.main.path(forResource: "ringtone", ofType: "mp3"),
                Bundle.main.path(forResource: "ringtone", ofType: "wav"),
                Bundle.main.path(forResource: "notes_of_the_optimistic", ofType: "mkv", inDirectory: "Frameworks/linphone.framework")
            ]
            
            // 尝试找到并使用第一个可用的铃声文件
            for path in ringtonePaths.compactMap({ $0 }) {
                do {
                    print("[IncomingCallView] 尝试加载铃声文件: \(path)")
                    let url = URL(fileURLWithPath: path)
                    let audioPlayer = try AVAudioPlayer(contentsOf: url)
                
                // 配置音频会话
                try AVAudioSession.sharedInstance().setCategory(.playback, options: [.defaultToSpeaker, .mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                    
                    audioPlayer.numberOfLoops = -1
                    audioPlayer.prepareToPlay()
                    self.audioPlayer = audioPlayer
                    
                    print("[IncomingCallView] 铃声设置成功: \(path)")
                    return
                } catch {
                    print("[IncomingCallView] 加载铃声失败: \(path), 错误: \(error)")
                    continue
                }
            }
            
            // 如果所有铃声文件都加载失败，使用系统声音
            useFallbackSound()
            
        } catch {
            print("[IncomingCallView] 设置铃声过程中出错: \(error)")
            // 使用系统提示音作为最后的备选方案
            AudioServicesPlaySystemSound(1007)
        }
    }
    
    private func startRinging() {
        #if !targetEnvironment(simulator)
        // 只在真机上播放铃声
        setupRingtone()
        #else
        // 在模拟器上只显示来电界面
        print("[IncomingCallView] 模拟器环境，跳过铃声播放")
        #endif
    }
    
    private func stopRinging() {
        isRinging = false
        // 铃声停止由IncomingCallDisplayHelper处理
    }
}

struct IncomingCallView_Previews: PreviewProvider {
    static var previews: some View {
        if let currentCall = SipManager.shared.currentCall {
            IncomingCallView(call: currentCall, callerName: "张三", callerNumber: "123456")
        } else {
            Text("No current call available for preview")
        }
    }
}
