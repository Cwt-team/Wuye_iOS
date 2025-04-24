import SwiftUI

struct UnlockView: View {
    // 手动输入门锁编号
    @State private var manualCode: String = ""
    // 扫码视图是否展示（可接入真实扫码库）
    @State private var isShowingScanner = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // 1. 扫码开锁区域
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 280, height: 280)
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode.viewfinder")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.purple)
                        Text("扫码开锁")
                            .font(.headline)
                            .foregroundColor(.purple)
                    }
                }
                .onTapGesture {
                    // TODO: 跳转到扫码逻辑，比如：isShowingScanner = true
                }

                // 2. 手动输入开锁
                VStack(spacing: 12) {
                    Text("手动输入开锁")
                        .font(.headline)
                        .foregroundColor(.purple)
                    TextField("请输入门锁编号", text: $manualCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.secondarySystemFill))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 1))
                    Button(action: {
                        // TODO: 根据 manualCode 调用开锁接口
                    }) {
                        Text("开 锁")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(manualCode.isEmpty ? Color.gray : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(manualCode.isEmpty)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("开锁")
            .navigationBarTitleDisplayMode(.inline)
            // .sheet(isPresented: $isShowingScanner) { ScannerView(...) }
            .accentColor(.purple)
        }
    }
}

struct UnlockView_Previews: PreviewProvider {
    static var previews: some View {
        UnlockView()
    }
}
