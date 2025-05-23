import SwiftUI

struct Contact: Identifiable {
    var id = UUID()
    var name: String
    var phoneNumber: String
    var isOnline: Bool = false
}

struct ContactListView: View {
    @State private var contacts = [
        Contact(name: "张三", phoneNumber: "1000", isOnline: true),
        Contact(name: "李四", phoneNumber: "1001", isOnline: true),
        Contact(name: "王五", phoneNumber: "1002", isOnline: false),
        Contact(name: "赵六", phoneNumber: "1003", isOnline: true),
        Contact(name: "钱七", phoneNumber: "1004", isOnline: false)
    ]
    
    @State private var searchText = ""
    @State private var isShowingCallView = false
    @State private var selectedContact: Contact?
    @State private var showAddContact = false
    
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        } else {
            return contacts.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.phoneNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(filteredContacts) { contact in
                        ContactRow(contact: contact) {
                            selectedContact = contact
                            isShowingCallView = true
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                // 拨号按钮
                VStack {
                    Button(action: {
                        showAddContact = true
                    }) {
                        HStack {
                            Image(systemName: "phone.circle.fill")
                                .font(.system(size: 22))
                            Text("拨号")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .padding(.bottom)
                }
                .padding(.horizontal)
            }
            .navigationTitle("联系人")
            .searchable(text: $searchText, prompt: "搜索联系人或号码")
            .sheet(isPresented: $isShowingCallView) {
                if let contact = selectedContact {
                    CallView(callerName: contact.name, callerNumber: contact.phoneNumber, isIncoming: false)
                }
            }
            .sheet(isPresented: $showAddContact) {
                DialPadView { number in
                    showAddContact = false
                    if !number.isEmpty {
                        // 直接拨打电话
                        selectedContact = Contact(name: "直接拨号", phoneNumber: number)
                        isShowingCallView = true
                    }
                }
            }
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // 头像
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(String(contact.name.prefix(1)))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                // 联系人信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(contact.phoneNumber)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 在线状态
                Circle()
                    .fill(contact.isOnline ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                
                // 呼叫按钮
                Image(systemName: "phone.fill")
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DialPadView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var phoneNumber = ""
    var onDial: (String) -> Void
    
    let keypad = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["*", "0", "#"]
    ]
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
            }
            
            Spacer()
            
            // 号码显示
            Text(phoneNumber.isEmpty ? "输入号码" : phoneNumber)
                .font(.system(size: 32, weight: .medium))
                .padding()
                .frame(height: 60)
            
            // 键盘
            VStack(spacing: 15) {
                ForEach(keypad, id: \.self) { row in
                    HStack(spacing: 30) {
                        ForEach(row, id: \.self) { key in
                            Button(action: {
                                phoneNumber += key
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(width: 70, height: 70)
                                    
                                    Text(key)
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // 呼叫和删除按钮
                HStack(spacing: 30) {
                    // 删除按钮
                    Button(action: {
                        if !phoneNumber.isEmpty {
                            phoneNumber.removeLast()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "delete.left")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 呼叫按钮
                    Button(action: {
                        onDial(phoneNumber)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "phone.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(phoneNumber.isEmpty)
                    .opacity(phoneNumber.isEmpty ? 0.5 : 1)
                    
                    // 占位按钮，保持对称
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 70, height: 70)
                }
            }
            .padding()
            
            Spacer()
        }
    }
}

struct ContactListView_Previews: PreviewProvider {
    static var previews: some View {
        ContactListView()
    }
} 
