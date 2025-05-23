import SwiftUI
import Combine

/// 验证码输入视图
/// 提供了分隔的数字输入框，自动焦点管理，支持粘贴功能
struct VerificationCodeView: View {
    /// 验证码长度，默认为6位
    var codeLength: Int = 6
    
    /// 输入框间距
    var spacing: CGFloat = 8
    
    /// 输入框样式配置
    var boxWidth: CGFloat = 45
    var boxHeight: CGFloat = 55
    var cornerRadius: CGFloat = 8
    var borderWidth: CGFloat = 1
    
    /// 验证码输入后回调
    var onCodeCompleted: (String) -> Void = { _ in }
    
    /// 输入框颜色配置
    var borderColor: Color = Color.gray.opacity(0.3)
    var filledBorderColor: Color = Color.purple
    var backgroundColor: Color = Color(.secondarySystemBackground)
    var textColor: Color = Color.primary
    
    /// 绑定的验证码
    @Binding var code: String
    
    /// 当前激活的输入框索引
    @State private var focusedIndex: Int = 0
    
    /// iOS 15以上支持FocusState
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<codeLength, id: \.self) { index in
                ZStack {
                    // 输入框背景和边框
                    Rectangle()
                        .fill(backgroundColor)
                        .frame(width: boxWidth, height: boxHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(getBoxIndex(index) < code.count ? filledBorderColor : borderColor, lineWidth: borderWidth)
                        )
                        .cornerRadius(cornerRadius)
                    
                    // 显示用户输入的字符
                    if getBoxIndex(index) < code.count {
                        let codeIndex = code.index(code.startIndex, offsetBy: getBoxIndex(index))
                        Text(String(code[codeIndex]))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(textColor)
                    }
                }
                .onTapGesture {
                    // 点击任何输入框时设置焦点
                    focusedIndex = index
                    isFocused = true
                }
            }
        }
        .overlay(
            // 隐藏的文本框用于捕获键盘输入
            TextField("", text: $code)
                .frame(width: 0, height: 0)
                .opacity(0)
                .focused($isFocused)
                .keyboardType(.numberPad)
                #if swift(>=5.9)
                .onChange(of: code) { newValue in
                    processCodeChange(newValue)
                }
                #else
                .onChange(of: code) { newValue in
                    processCodeChange(newValue)
                }
                #endif
                .onAppear {
                    // 首次显示时自动获取焦点
                    isFocused = true
                }
        )
    }
    
    /// 处理验证码变化
    private func processCodeChange(_ newValue: String) {
        // 限制只能输入数字
        let filtered = newValue.filter { "0123456789".contains($0) }
        if filtered != newValue {
            code = filtered
        }
        
        // 限制最大长度
        if newValue.count > codeLength {
            code = String(newValue.prefix(codeLength))
        }
        
        // 当验证码输入完成时调用回调
        if code.count == codeLength {
            onCodeCompleted(code)
        }
    }
    
    /// 获取对应索引的输入框当前显示的文本索引
    private func getBoxIndex(_ index: Int) -> Int {
        return index
    }
}

#Preview {
    VStack {
        Text("验证码输入示例")
            .font(.headline)
        
        VerificationCodeView(
            codeLength: 6,
            onCodeCompleted: { code in
                print("输入的验证码: \(code)")
            },
            code: .constant("")
        )
        .padding()
    }
} 
