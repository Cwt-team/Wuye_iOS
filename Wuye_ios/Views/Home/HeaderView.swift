import SwiftUI

struct HeaderView: View {
    var body: some View {
        HStack(spacing: 16) {
            Image("avatar")
                .resizable()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                Text("李清照")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("汤臣一品")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            Text("在线")
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
        }
        .padding()
        .background(Color.purple)
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView()
    }
}
