import SwiftUI

struct NotificationView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.purple)
                Text("暂无通知")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            
            Divider()
            
            Text("你暂时没有收到任何消息哦~")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .accentColor(.purple)
    }
}

struct NotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationView()
    }
}
