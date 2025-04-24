import SwiftUI

struct BannerView: View {
    let images = ["banner1", "banner2"]
    @State private var currentIndex = 0

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(images.indices, id: \.self) { idx in
                Image(images[idx])
                    .resizable()
                    .scaledToFill()
                    .tag(idx)
                    .clipped()
            }
        }
        .frame(height: 180)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .accentColor(.purple)
        .background(Color.white)
    }
}

struct BannerView_Previews: PreviewProvider {
    static var previews: some View {
        BannerView()
    }
}
