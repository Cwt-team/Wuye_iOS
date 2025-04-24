import SwiftUI

struct Feature: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
}

struct FeatureGridView: View {
    let features: [Feature] = [
        .init(imageName: "icon_chat", title: "户户通"),
        .init(imageName: "icon_monitor", title: "监控"),
        .init(imageName: "icon_qrcode", title: "扫码开门"),
        .init(imageName: "icon_record", title: "呼叫记录"),
        .init(imageName: "icon_bell", title: "社区通知"),
        .init(imageName: "icon_alert", title: "报警记录"),
        .init(imageName: "icon_wrench", title: "报事报修"),
        .init(imageName: "icon_more", title: "更多")
    ]
    let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(features) { f in
                VStack(spacing: 8) {
                    Image(f.imageName)
                        .resizable()
                        .frame(width: 40, height: 40)
                    Text(f.title)
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .background(Color.white)
    }
}

struct FeatureGridView_Previews: PreviewProvider {
    static var previews: some View {
        FeatureGridView()
    }
}
