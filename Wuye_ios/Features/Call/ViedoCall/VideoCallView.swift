import SwiftUI
import linphonesw

/// 视频通话主界面
struct VideoCallView: View {
    @EnvironmentObject var videoCallManager: VideoCallManager
    @EnvironmentObject var sipManager: SipManager // 确保 SipManager 是 EnvironmentObject
    let call: linphonesw.Call // This `call` might be the initial incoming call from the previous screen.
    let callerName: String
    let callerNumber: String
    
    // 新增：用于在视图出现后触发 Linphone 接受呼叫
    @State private var hasProcessedCall: Bool = false

    var body: some View {
        ZStack {
            // 远端视频画面
            LinphoneVideoView(isLocal: false) { uiView in
                // 在此处将实际的 UIView 实例设置到 SipManager
                sipManager.remoteVideoView = uiView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 本地视频画中画
            LinphoneVideoView(isLocal: true) { uiView in
                // 在此处将实际的 UIView 实例设置到 SipManager
                sipManager.localVideoView = uiView
            }
            .frame(width: 120, height: 160)
            .cornerRadius(10)
            .shadow(radius: 5)
            .padding(20)
            .offset(x: UIScreen.main.bounds.width / 2 - 120, y: -UIScreen.main.bounds.height / 2 + 180) // 调整位置
            
            // 通话控制按钮
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    // 静音
                    Button(action: {
                        videoCallManager.toggleMute()
                    }) {
                        Image(systemName: videoCallManager.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    // 挂断
                    Button(action: {
                        videoCallManager.hangup()
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    
                    // 切换摄像头
                    Button(action: {
                        videoCallManager.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // 在视图出现时，标记视频视图已准备就绪
            // 确保只处理一次
            if !hasProcessedCall {
                print("【VideoCallView】视图已出现，标记视频视图已准备就绪，尝试处理待处理来电。")
                videoCallManager.areVideoViewsReady = true
                // 这里不再直接调用 videoCallManager.acceptVideoCall(call: call)，而是调用 processPendingIncomingCall
                // 因为 acceptVideoCall 现在只是存储了呼叫，需要等待视图准备好才真正处理
                videoCallManager.processPendingIncomingCall() // 触发处理待处理来电
                hasProcessedCall = true
                // 这里再去执行接听逻辑
                SipManager.shared.acceptCall()
            }
        }
        .onDisappear {
            videoCallManager.hangup()
        }
    }
}

/// Linphone 视频视图的 SwiftUI 包装器
struct LinphoneVideoView: UIViewRepresentable {
    var isLocal: Bool
    // 添加一个回调，用于在 UIView 创建时传递其实例
    var onVideoViewCreated: ((UIView) -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = isLocal ? .gray : .black
        print("【调试】\(isLocal ? "本地" : "远端") LinphoneVideoView 成功创建了 UIView: \(view)")

        // 立即调用回调，传递创建的 UIView 实例
        onVideoViewCreated?(view)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update view if needed (e.g., orientation changes)
    }

    // 当 SwiftUI 视图被销毁时，清理 SipManager 中的引用
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        print("【调试】\(uiView == SipManager.shared.localVideoView ? "本地" : "远端") LinphoneVideoView 的 UIView 正在被销毁...")
        if uiView == SipManager.shared.localVideoView {
            SipManager.shared.clearLocalVideoView() // 调用公共方法清理本地视频视图
            print("【调试】本地视频视图引用已通过 clearLocalVideoView() 清除。")
        } else if uiView == SipManager.shared.remoteVideoView {
            SipManager.shared.clearRemoteVideoView() // 调用公共方法清理远端视频视图
            print("【调试】远端视频视图引用已通过 clearRemoteVideoView() 清除。")
        }
    }
}

