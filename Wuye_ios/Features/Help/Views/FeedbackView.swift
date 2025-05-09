import SwiftUI

/// 用户反馈视图
struct FeedbackView: View {
    // 反馈内容
    @State private var feedbackText = ""
    @State private var selectedCategory = FeedbackCategory.suggestion
    @State private var contactInfo = ""
    @State private var includeDeviceInfo = true
    @State private var includeScreenshots = false
    @State private var selectedImages: [UIImage] = []
    
    // UI状态
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var showingImagePicker = false
    @State private var alertMessage = ""
    @State private var showingActionSheet = false
    
    // 反馈类别选项
    enum FeedbackCategory: String, CaseIterable, Identifiable {
        case bug = "问题反馈"
        case suggestion = "功能建议"
        case complaint = "投诉"
        case praise = "表扬"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        Form {
            // 反馈类别选择
            Section(header: Text("反馈类别")) {
                Picker("选择类别", selection: $selectedCategory) {
                    ForEach(FeedbackCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // 反馈内容
            Section(header: Text("反馈内容")) {
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 150)
                    .overlay(
                        VStack {
                            if feedbackText.isEmpty {
                                HStack {
                                    Text(placeholderText)
                                        .foregroundColor(.gray)
                                        .padding(.leading, 5)
                                        .padding(.top, 8)
                                    Spacer()
                                }
                            }
                            Spacer()
                        }
                    )
                
                if selectedImages.count > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(0..<selectedImages.count, id: \.self) { index in
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        Button(action: {
                                            selectedImages.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.7))
                                                .clipShape(Circle())
                                        }
                                        .padding(4),
                                        alignment: .topTrailing
                                    )
                                    .padding(4)
                            }
                        }
                    }
                }
                
                Button(action: {
                    showingActionSheet = true
                }) {
                    HStack {
                        Image(systemName: "photo")
                        Text("添加图片")
                    }
                }
                .disabled(selectedImages.count >= 4)
            }
            
            // 联系方式
            Section(header: Text("联系方式（选填）"),
                    footer: Text("留下您的联系方式，方便我们联系您")) {
                TextField("邮箱或手机号", text: $contactInfo)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // 其他选项
            Section(header: Text("其他选项"),
                    footer: Text("设备信息有助于我们更好地分析问题")) {
                Toggle("包含设备信息", isOn: $includeDeviceInfo)
                
                if includeDeviceInfo {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("iOS \(UIDevice.current.systemVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(UIDevice.current.model)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
            
            // 提交按钮
            Section {
                Button(action: submitFeedback) {
                    HStack {
                        Spacer()
                        
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("提交反馈")
                                .bold()
                        }
                        
                        Spacer()
                    }
                }
                .disabled(feedbackText.count < 10 || isSubmitting)
            }
        }
        .navigationTitle("意见反馈")
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("反馈结果"),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("选择图片"),
                buttons: [
                    .default(Text("拍照")) {
                        showingImagePicker = true
                        // 实际应用中设置图片来源为摄像头
                    },
                    .default(Text("从相册选择")) {
                        showingImagePicker = true
                        // 实际应用中设置图片来源为相册
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
        // 在实际应用中需要实现图片选择器
        // .sheet(isPresented: $showingImagePicker) {
        //     ImagePicker(selectedImages: $selectedImages, isPresented: $showingImagePicker)
        // }
    }
    
    // 反馈类别对应的占位文本
    var placeholderText: String {
        switch selectedCategory {
        case .bug:
            return "请描述您遇到的问题，包括操作步骤和现象，这有助于我们快速定位和解决问题。"
        case .suggestion:
            return "请描述您的功能建议，越具体越好。"
        case .complaint:
            return "请详细描述您的投诉内容，我们将认真处理。"
        case .praise:
            return "感谢您的肯定，请告诉我们您喜欢的功能或体验。"
        }
    }
    
    // 提交反馈
    private func submitFeedback() {
        // 表单验证
        if feedbackText.count < 10 {
            alertMessage = "反馈内容不能少于10个字符"
            showingAlert = true
            return
        }
        
        // 开始提交
        isSubmitting = true
        
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 实际提交逻辑
            
            // 重置表单
            self.feedbackText = ""
            self.selectedImages = []
            
            // 显示成功消息
            self.alertMessage = "感谢您的反馈！我们会尽快处理并回复您。"
            self.showingAlert = true
            self.isSubmitting = false
        }
    }
}

// 预览
struct FeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FeedbackView()
        }
    }
} 