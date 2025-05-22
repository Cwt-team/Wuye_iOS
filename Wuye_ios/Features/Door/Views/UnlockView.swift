import SwiftUI

struct UnlockView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedDoor: Door? = nil
    @State private var isShowingDoorDetail = false
    @State private var doors: [Door] = []
    
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentUnavailableView("暂无内容", systemImage: "lock", description: Text("请稍后重试"))
            } else {
                // iOS 16 及以下自定义占位视图
                VStack(spacing: 12) {
                    Image(systemName: "lock")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("暂无内容")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("请稍后重试")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("门禁开锁")
        .sheet(isPresented: $isShowingDoorDetail) {
            if let door = selectedDoor {
                DoorDetailView(door: door)
            }
        }
        .onAppear {
            loadDoors()
        }
    }
    
    private func loadDoors() {
        // 这里应该从API或本地数据库加载门禁数据
        // 目前使用模拟数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.doors = [
                Door(id: 1, propertyId: 1, name: "小区大门", doorCode: "001", doorType: "main", isActive: true),
                Door(id: 2, propertyId: 1, name: "1号楼门禁", doorCode: "002", doorType: "building", isActive: true),
                Door(id: 3, propertyId: 1, name: "健身房", doorCode: "003", doorType: "facility", isActive: true),
                Door(id: 4, propertyId: 1, name: "游泳池", doorCode: "004", doorType: "facility", isActive: false)
            ]
        }
    }
}

// 门禁列表项
struct DoorListItem: View {
    let door: Door
    
    var body: some View {
        HStack {
            Image(systemName: door.isActive ? "lock.open.fill" : "lock.fill")
                .foregroundColor(door.isActive ? .green : .gray)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(door.isActive ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(door.name)
                    .font(.headline)
                Text("门禁编号: \(door.doorCode)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

// 门禁详细页面
struct DoorDetailView: View {
    let door: Door
    @Environment(\.presentationMode) var presentationMode
    @State private var isUnlocking = false
    @State private var unlockResult: Bool? = nil
    
    var body: some View {
        VStack(spacing: 30) {
            // 顶部标题栏
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(door.name)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 平衡布局的空按钮
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.clear)
            }
            .padding()
            
            Spacer()
            
            // 门禁图标
            Image(systemName: unlockResult == true ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 80))
                .foregroundColor(unlockResult == true ? .green : (unlockResult == false ? .red : .primary))
                .frame(width: 150, height: 150)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                )
                .overlay(
                    Circle()
                        .stroke(unlockResult == true ? Color.green : (unlockResult == false ? Color.red : Color.gray), lineWidth: 4)
                )
            
            // 状态文本
            Text(isUnlocking ? "开锁中..." : (unlockResult == true ? "开锁成功" : (unlockResult == false ? "开锁失败" : "点击按钮开锁")))
                .font(.title3)
                .foregroundColor(unlockResult == true ? .green : (unlockResult == false ? .red : .primary))
            
            // 详细信息
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(title: "门禁名称", value: door.name)
                InfoRow(title: "门禁编号", value: door.doorCode)
                InfoRow(title: "门禁类型", value: door.doorType)
                InfoRow(title: "门禁状态", value: door.isActive ? "可用" : "不可用")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal)
            
            Spacer()
            
            // 开锁按钮
            Button(action: {
                unlockDoor()
            }) {
                Text("开锁")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(door.isActive ? Color.blue : Color.gray)
                    )
            }
            .disabled(!door.isActive || isUnlocking)
            .padding(.bottom, 30)
        }
    }
    
    private func unlockDoor() {
        guard door.isActive else { return }
        
        isUnlocking = true
        unlockResult = nil
        
        // 模拟开锁过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isUnlocking = false
            // 随机成功或失败，实际应用中应调用API
            self.unlockResult = Bool.random()
        }
    }
}

// 信息行组件
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title + ":")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
        }
    }
}

struct UnlockView_Previews: PreviewProvider {
    static var previews: some View {
        UnlockView()
            .environmentObject(AuthManager.shared)
    }
} 
