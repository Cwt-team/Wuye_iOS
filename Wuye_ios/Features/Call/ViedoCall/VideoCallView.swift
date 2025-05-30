import SwiftUI
import linphonesw

/// 视频通话主界面
struct VideoCallView: View {
    @ObservedObject var manager: VideoCallManager = .shared
    let call: linphonesw.Call
    let callerName: String
    let callerNumber: String
    
    var body: some View {
        ZStack {
            // 远端视频画面
            RemoteVideoView()
                .edgesIgnoringSafeArea(.all)
            
            // 本地视频画中画
            VStack {
                HStack {
                    Spacer()
                    LocalVideoView()
                        .frame(width: 120, height: 160)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .padding()
                }
                Spacer()
            }
            
            // 通话控制按钮
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    // 静音
                    Button(action: {
                        manager.toggleMute()
                    }) {
                        Image(systemName: manager.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    // 挂断
                    Button(action: {
                        manager.hangup()
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
                        manager.switchCamera()
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
            // 可在此处初始化视频通话或监听状态
        }
        .onDisappear {
            // 退出时挂断通话
            manager.hangup()
        }
    }
}

/// 远端视频画面（需用SIP库渲染视频流）
struct RemoteVideoView: View {
    var body: some View {
        // 这里用占位，实际项目中用 UIViewRepresentable 嵌入 linphone/pjsip 的视频渲染View
        Color.black
            .overlay(Text("远端视频").foregroundColor(.white))
    }
}

/// 本地视频画面（需用SIP库渲染本地摄像头流）
struct LocalVideoView: View {
    var body: some View {
        // 这里用占位，实际项目中用 UIViewRepresentable 嵌入 linphone/pjsip 的本地视频View
        Color.gray
            .overlay(Text("本地视频").foregroundColor(.white))
    }
}
