import SwiftUI

struct Service: Identifiable {
    let id = UUID()
    let imageName: String
}

struct LifeServiceView: View {
    let services: [Service] = [
        .init(imageName: "service1"),
        .init(imageName: "service2"),
        .init(imageName: "service3"),
        // ... 更多
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("生活服务")
                .font(.headline)
                .foregroundColor(.purple)
                .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(services) { s in
                        Image(s.imageName)
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color.white)
        .accentColor(.purple)
    }
}

struct LifeServiceView_Previews: PreviewProvider {
    static var previews: some View {
        LifeServiceView()
    }
}
