import SwiftUI
import AVFoundation
import AudioToolbox
import linphonesw

struct IncomingCallView: View {
    @ObservedObject private var sipManager = SipManager.shared
    @State private var showCallView = false
    @State private var callAccepted = false

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
                        sipManager.terminateCall()
                        callManager.clearIncomingCall()
                        self.presentationMode.wrappedValue.dismiss()
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
                        print("点击接听")
                        showCallView = true
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
            // 只由CallManager统一控制振铃，这里不再播放铃声
        }
        .onDisappear {
            print("[IncomingCallView] 视图消失")
            // 只由CallManager统一控制振铃，这里不再停止铃声
            // 如果没有接听，且不是通过CallView离开的，则拒绝来电
            if !callAccepted && !showCallView {
                sipManager.terminateCall()
                CallManager.shared.clearIncomingCall()
            }
        }
        .fullScreenCover(isPresented: $showCallView) {
            VideoCallView(call: call, callerName: callerName, callerNumber: callerNumber)
                .environmentObject(SipManager.shared)
                .environmentObject(VideoCallManager.shared)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("IncomingCallEnded"))) { _ in
            self.showCallView = false
        }
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
