import SwiftUI
import PhotosUI

/// 创建报修单视图
struct CreateReportView: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var isPresented: Bool
    
    // 表单数据
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: RepairReport.Category = .water
    @State private var location: String = ""
    @State private var contactPhone: String = ""
    
    // 照片选择
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    
    // UI 状态
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // 基本信息
                Section(header: Text("基本信息")) {
                    TextField("标题", text: $title)
                        .autocapitalization(.none)
                    
                    Picker("类别", selection: $category) {
                        ForEach(RepairReport.Category.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    
                    TextField("位置", text: $location)
                        .autocapitalization(.none)
                    
                    TextField("联系电话", text: $contactPhone)
                        .keyboardType(.phonePad)
                }
                
                // 详细描述
                Section(header: Text("详细描述")) {
                    TextEditor(text: $description)
                        .frame(height: 150)
                }
                
                // 照片上传
                Section(header: Text("上传照片（可选）")) {
                    PhotosPicker(selection: $photoPickerItems, matching: .images) {
                        Label("选择照片", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: photoPickerItems) { newValue in
                        loadImages(from: newValue)
                    }
                    
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(0..<selectedImages.count, id: \.self) { index in
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
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
                                            .padding(5),
                                            alignment: .topTrailing
                                        )
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                
                // 提交按钮
                Section {
                    Button(action: submitReport) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("提交报修")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || title.isEmpty || location.isEmpty || contactPhone.isEmpty)
                }
            }
            .navigationTitle("创建报修单")
            .navigationBarItems(
                trailing: Button("取消") {
                    isPresented = false
                }
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
            .alert("报修单已创建", isPresented: $showingSuccessAlert) {
                Button("确定", role: .cancel) {
                    isPresented = false
                }
            } message: {
                Text("您的报修单已成功提交，我们会尽快处理。")
            }
            .onAppear {
                if let user = authManager.currentUser {
                    contactPhone = user.phone
                }
            }
        }
    }
    
    // 加载照片
    private func loadImages(from items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            selectedImages.append(image)
                        }
                    }
                case .failure(let error):
                    print("照片加载失败: \(error)")
                }
            }
        }
    }
    
    // 验证表单
    private func validateForm() -> Bool {
        if title.isEmpty {
            alertMessage = "请输入报修标题"
            showingAlert = true
            return false
        }
        
        if location.isEmpty {
            alertMessage = "请输入报修位置"
            showingAlert = true
            return false
        }
        
        if contactPhone.isEmpty {
            alertMessage = "请输入联系电话"
            showingAlert = true
            return false
        }
        
        // 简单的电话号码验证
        if !contactPhone.starts(with: "1") || contactPhone.count != 11 {
            alertMessage = "请输入有效的手机号码"
            showingAlert = true
            return false
        }
        
        return true
    }
    
    // 提交报修单
    private func submitReport() {
        if !validateForm() {
            return
        }
        
        isSaving = true
        
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSaving = false
            
            // 模拟成功响应
            showingSuccessAlert = true
        }
    }
}

// 预览
struct CreateReportView_Previews: PreviewProvider {
    static var previews: some View {
        CreateReportView(isPresented: .constant(true))
            .environmentObject(AuthManager.shared)
    }
} 