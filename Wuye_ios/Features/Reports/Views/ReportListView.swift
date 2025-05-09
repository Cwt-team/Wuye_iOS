import SwiftUI

/// 报修列表视图
struct ReportListView: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var isCreateReportSheetPresented: Bool
    @State private var reports: [RepairReport] = []
    @State private var selectedFilter: ReportFilter = .all
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    // 筛选选项
    enum ReportFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case pending = "待处理"
        case processing = "处理中"
        case completed = "已完成"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 报修状态筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ReportFilter.allCases) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                action: {
                                    selectedFilter = filter
                                    loadReports()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                if isLoading {
                    // 加载指示器
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    Spacer()
                } else if let errorMessage = errorMessage {
                    // 错误信息
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text(errorMessage)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Button("重试") {
                            loadReports()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    Spacer()
                } else if reports.isEmpty {
                    // 空状态
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("暂无报修记录")
                            .font(.headline)
                        
                        Text("点击下方按钮创建新的报修单")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            isCreateReportSheetPresented = true
                        }) {
                            Text("创建报修单")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    Spacer()
                } else {
                    // 报修列表
                    List {
                        ForEach(reports) { report in
                            ReportRow(report: report)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // 点击查看详情
                                }
                        }
                    }
                    .refreshable {
                        loadReports()
                    }
                }
            }
            .navigationTitle("我的报修")
            .navigationBarItems(
                trailing: Button(action: {
                    isCreateReportSheetPresented = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .onAppear {
                loadReports()
            }
        }
    }
    
    // 加载报修列表
    private func loadReports() {
        isLoading = true
        errorMessage = nil
        
        // 模拟网络加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 生成模拟数据
            reports = generateMockReports()
            isLoading = false
        }
    }
    
    // 生成测试数据
    private func generateMockReports() -> [RepairReport] {
        // 根据筛选条件生成数据
        switch selectedFilter {
        case .all:
            return [
                RepairReport.mock(status: .pending),
                RepairReport.mock(status: .processing),
                RepairReport.mock(status: .completed)
            ]
        case .pending:
            return [RepairReport.mock(status: .pending)]
        case .processing:
            return [RepairReport.mock(status: .processing)]
        case .completed:
            return [RepairReport.mock(status: .completed)]
        }
    }
}

// 筛选芯片
struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// 报修行
struct ReportRow: View {
    var report: RepairReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(report.title)
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(status: report.status)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.gray)
                Text(report.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.gray)
                Text(report.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if let assignee = report.assignee {
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.gray)
                    Text("处理人: \(assignee)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// 状态标签
struct StatusBadge: View {
    var status: RepairReport.Status
    
    var body: some View {
        Text(status.displayText)
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(4)
    }
}

// 报修记录模型
struct RepairReport: Identifiable {
    let id: String
    let title: String
    let description: String
    let category: Category
    let images: [String]?
    let location: String
    let date: Date
    let status: Status
    let assignee: String?
    let contactPhone: String
    
    enum Category: String, CaseIterable {
        case water = "水电维修"
        case electricity = "电路维修"
        case furniture = "家具维修"
        case appliance = "家电维修"
        case publicArea = "公共区域"
        case other = "其他"
    }
    
    enum Status: String, CaseIterable {
        case pending = "待处理"
        case processing = "处理中"
        case completed = "已完成"
        
        var displayText: String {
            return self.rawValue
        }
        
        var color: Color {
            switch self {
            case .pending:
                return .orange
            case .processing:
                return .blue
            case .completed:
                return .green
            }
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
    
    static func mock(status: Status) -> RepairReport {
        let titles = [
            "水龙头漏水",
            "厨房灯具不亮",
            "卧室门把手松动",
            "空调不制冷",
            "热水器漏水",
            "洗手间下水道堵塞"
        ]
        
        let locations = [
            "1号楼2单元101",
            "2号楼1单元303",
            "3号楼3单元502",
            "4号楼2单元205",
            "5号楼1单元601"
        ]
        
        let descriptions = [
            "厨房水龙头一直在滴水，需要更换密封圈",
            "厨房灯具按下开关后不亮，可能是灯泡坏了或者线路问题",
            "卧室门把手松动，开关门时有异响",
            "空调开机后不制冷，出风正常但温度不变",
            "热水器底部有水渗出，可能是接口处密封不严",
            "洗手间下水道排水缓慢，可能是堵塞了"
        ]
        
        return RepairReport(
            id: UUID().uuidString,
            title: titles.randomElement()!,
            description: descriptions.randomElement()!,
            category: Category.allCases.randomElement()!,
            images: nil,
            location: locations.randomElement()!,
            date: Date().addingTimeInterval(-Double.random(in: 0...(86400 * 30))),
            status: status,
            assignee: status == .pending ? nil : "张师傅",
            contactPhone: "13800138000"
        )
    }
}

// 预览
struct ReportListView_Previews: PreviewProvider {
    static var previews: some View {
        ReportListView(isCreateReportSheetPresented: .constant(false))
            .environmentObject(AuthManager.shared)
    }
} 