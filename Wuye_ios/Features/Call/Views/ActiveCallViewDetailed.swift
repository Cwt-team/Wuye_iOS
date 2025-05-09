import SwiftUI

struct ActiveCallViewDetailed: View {
    @EnvironmentObject private var callManager: CallManager
    let callerName: String
    let callerNumber: String
    
    private var callDuration: String {
        guard let startTime = callManager.callStartTime else {
            return "00:00"
        }
        let duration = Int(Date().timeIntervalSince(startTime))
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    @State private var isMuted: Bool = false
    @State private var isSpeakerOn: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(callerName)
                .font(.title)
            
            Text(callerNumber)
                .font(.subheadline)
            
            Text(callDuration)
                .font(.headline)
                .padding(.top, 10)
            
            HStack(spacing: 40) {
                Button(action: {
                    isMuted.toggle()
                    callManager.toggleMute()
                }) {
                    VStack {
                        Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 30))
                        Text("静音")
                            .font(.caption)
                    }
                }
                
                Button(action: {
                    isSpeakerOn.toggle()
                    callManager.toggleSpeaker()
                }) {
                    VStack {
                        Image(systemName: isSpeakerOn ? "speaker.wave.2.fill" : "speaker.fill")
                            .font(.system(size: 30))
                        Text("扬声器")
                            .font(.caption)
                    }
                }
            }
            .padding(.top, 30)
            
            Button(action: {
                callManager.endCall()
            }) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .padding(20)
                    .background(Circle().fill(Color.red))
            }
            .padding(.top, 40)
        }
        .padding()
    }
}

struct ActiveCallViewDetailed_Previews: PreviewProvider {
    static var previews: some View {
        ActiveCallViewDetailed(callerName: "测试用户", callerNumber: "1001")
            .environmentObject(CallManager())
    }
} 