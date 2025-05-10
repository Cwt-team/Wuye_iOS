import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var callManager: CallManager
    @StateObject private var viewModel = MapViewModel()
    @State private var showFilterOptions = false
    @State private var searchText = ""
    @State private var selectedPlace: PlaceAnnotation?
    @State private var showingCallAlert = false
    
    var body: some View {
        ZStack {
            // 地图视图
            Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.filteredPlaces) { place in
                MapAnnotation(coordinate: place.coordinate) {
                    PlaceMarker(place: place, isSelected: selectedPlace?.id == place.id) {
                        selectedPlace = place
                    }
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            
            // 顶部搜索栏
            VStack {
                HStack {
                    // 搜索栏
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("搜索地点", text: $searchText)
                            .onChange(of: searchText) { newValue in
                                viewModel.filterPlaces(by: newValue)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                viewModel.filterPlaces(by: "")
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                    
                    // 筛选按钮
                    Button(action: {
                        showFilterOptions.toggle()
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5)
                    }
                }
                .padding()
                
                Spacer()
                
                // 地图控制按钮
                VStack(spacing: 15) {
                    Button(action: {
                        viewModel.zoomIn()
                    }) {
                        Image(systemName: "plus")
                            .padding(10)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 3)
                    }
                    
                    Button(action: {
                        viewModel.zoomOut()
                    }) {
                        Image(systemName: "minus")
                            .padding(10)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 3)
                    }
                    
                    Button(action: {
                        viewModel.resetRegion()
                    }) {
                        Image(systemName: "location")
                            .padding(10)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 3)
                    }
                }
                .padding(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.bottom, 30)
            }
            
            // 筛选选项面板
            if showFilterOptions {
                VStack {
                    // 筛选选项
                    FilterOptionPanel(
                        selectedCategories: $viewModel.selectedCategories,
                        onApply: {
                            showFilterOptions = false
                            viewModel.applyFilters()
                        },
                        onReset: {
                            viewModel.resetFilters()
                        }
                    )
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 10)
                    .padding()
                    
                    Spacer()
                }
                .background(
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showFilterOptions = false
                        }
                )
                .zIndex(2)
            }
            
            // 底部详情卡片
            if let selectedPlace = selectedPlace {
                VStack {
                    Spacer()
                    
                    PlaceDetailCard(
                        place: selectedPlace,
                        onClose: { self.selectedPlace = nil },
                        onCall: {
                            showingCallAlert = true
                        }
                    )
                    .padding([.horizontal, .bottom])
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut, value: selectedPlace)
                }
                .zIndex(1)
            }
        }
        .navigationTitle("小区地图")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadPlaces()
        }
        .alert(isPresented: $showingCallAlert) {
            Alert(
                title: Text("拨打电话"),
                message: Text("确定要拨打 \(selectedPlace?.name ?? "") 的电话吗？"),
                primaryButton: .default(Text("确定")) {
                    if let place = selectedPlace {
                        callManager.makeCall(to: place.phoneNumber, name: place.name)
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
}

// 筛选选项面板
struct FilterOptionPanel: View {
    @Binding var selectedCategories: Set<PlaceCategory>
    var onApply: () -> Void
    var onReset: () -> Void
    
    let allCategories: [PlaceCategory] = PlaceCategory.allCases
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("筛选选项")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onReset) {
                    Text("重置")
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            Text("类型")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // 类别选择
            VStack(alignment: .leading, spacing: 10) {
                ForEach(allCategories, id: \.self) { category in
                    Button(action: {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }) {
                        HStack {
                            Image(systemName: selectedCategories.contains(category) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedCategories.contains(category) ? .blue : .gray)
                            
                            Text(category.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            Divider()
            
            // 应用按钮
            Button(action: onApply) {
                Text("应用筛选")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

// 地点标记
struct PlaceMarker: View {
    var place: PlaceAnnotation
    var isSelected: Bool
    var onTap: () -> Void
    
    var body: some View {
        ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                .shadow(color: Color.black.opacity(0.2), radius: 3)
            
            Image(systemName: place.category.iconName)
                .foregroundColor(.white)
                .font(.system(size: isSelected ? 20 : 16))
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
    
    // 根据类别获取标记颜色
    private var markerColor: Color {
        switch place.category {
        case .propertyManagement:
            return .blue
        case .security:
            return .red
        case .maintenance:
            return .orange
        case .amenity:
            return .green
        case .entrance:
            return .purple
        }
    }
}

// 地点详情卡片
struct PlaceDetailCard: View {
    var place: PlaceAnnotation
    var onClose: () -> Void
    var onCall: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Text(place.name)
                    .font(.headline)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            
            // 类别标签
            HStack {
                Label(place.category.displayName, systemImage: place.category.iconName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.2))
                    .foregroundColor(categoryColor)
                    .cornerRadius(4)
                
                if place.isOpen {
                    Label("营业中", systemImage: "clock")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else {
                    Label("已关闭", systemImage: "clock")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
            }
            
            // 地址
            HStack(alignment: .top) {
                Image(systemName: "mappin")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                Text(place.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 电话
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                Text(place.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onCall) {
                    Text("拨打")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
            }
            
            // 营业时间
            HStack(alignment: .top) {
                Image(systemName: "clock")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                Text(place.operatingHours)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 导航按钮
            Button(action: {
                // 导航功能
                openMapsApp(for: place)
            }) {
                HStack {
                    Spacer()
                    
                    Image(systemName: "location.fill")
                    Text("导航")
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
    }
    
    // 根据类别获取颜色
    private var categoryColor: Color {
        switch place.category {
        case .propertyManagement:
            return .blue
        case .security:
            return .red
        case .maintenance:
            return .orange
        case .amenity:
            return .green
        case .entrance:
            return .purple
        }
    }
    
    // 打开地图应用进行导航
    private func openMapsApp(for place: PlaceAnnotation) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// 地点类别枚举
enum PlaceCategory: String, CaseIterable, Identifiable {
    case propertyManagement = "propertyManagement"
    case security = "security"
    case maintenance = "maintenance"
    case amenity = "amenity"
    case entrance = "entrance"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .propertyManagement:
            return "物业服务"
        case .security:
            return "安保服务"
        case .maintenance:
            return "维修服务"
        case .amenity:
            return "便民设施"
        case .entrance:
            return "小区出入口"
        }
    }
    
    var iconName: String {
        switch self {
        case .propertyManagement:
            return "building.2"
        case .security:
            return "shield"
        case .maintenance:
            return "wrench"
        case .amenity:
            return "cart"
        case .entrance:
            return "door.left.hand.open"
        }
    }
}

// 地点注释模型
struct PlaceAnnotation: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let category: PlaceCategory
    let coordinate: CLLocationCoordinate2D
    let address: String
    let phoneNumber: String
    let operatingHours: String
    let isOpen: Bool
    
    // 实现Equatable协议
    static func == (lhs: PlaceAnnotation, rhs: PlaceAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}

// 地图视图模型
class MapViewModel: ObservableObject {
    // 地图区域
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074), // 示例坐标
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // 所有地点
    @Published var places: [PlaceAnnotation] = []
    
    // 筛选后的地点
    @Published var filteredPlaces: [PlaceAnnotation] = []
    
    // 选择的类别筛选
    @Published var selectedCategories: Set<PlaceCategory> = Set(PlaceCategory.allCases)
    
    // 搜索文本
    private var searchText: String = ""
    
    // 加载地点数据
    func loadPlaces() {
        // 在实际应用中，这些数据可能来自API
        places = [
            PlaceAnnotation(
                name: "物业管理中心",
                category: .propertyManagement,
                coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
                address: "小区中心广场旁",
                phoneNumber: "1001",
                operatingHours: "周一至周日 9:00-18:00",
                isOpen: true
            ),
            PlaceAnnotation(
                name: "安保中心",
                category: .security,
                coordinate: CLLocationCoordinate2D(latitude: 39.9050, longitude: 116.4080),
                address: "小区北门旁",
                phoneNumber: "1002",
                operatingHours: "24小时",
                isOpen: true
            ),
            PlaceAnnotation(
                name: "维修服务中心",
                category: .maintenance,
                coordinate: CLLocationCoordinate2D(latitude: 39.9035, longitude: 116.4067),
                address: "小区东侧维修楼",
                phoneNumber: "1003",
                operatingHours: "周一至周五 8:00-17:00",
                isOpen: true
            ),
            PlaceAnnotation(
                name: "小区超市",
                category: .amenity,
                coordinate: CLLocationCoordinate2D(latitude: 39.9048, longitude: 116.4063),
                address: "1号楼底商",
                phoneNumber: "1004",
                operatingHours: "周一至周日 7:00-22:00",
                isOpen: true
            ),
            PlaceAnnotation(
                name: "南门",
                category: .entrance,
                coordinate: CLLocationCoordinate2D(latitude: 39.9030, longitude: 116.4074),
                address: "小区南侧",
                phoneNumber: "1005",
                operatingHours: "24小时",
                isOpen: true
            ),
            PlaceAnnotation(
                name: "北门",
                category: .entrance,
                coordinate: CLLocationCoordinate2D(latitude: 39.9054, longitude: 116.4074),
                address: "小区北侧",
                phoneNumber: "1006",
                operatingHours: "24小时",
                isOpen: true
            ),
            PlaceAnnotation(
                name: "水电维修点",
                category: .maintenance,
                coordinate: CLLocationCoordinate2D(latitude: 39.9040, longitude: 116.4060),
                address: "小区西侧服务楼",
                phoneNumber: "1007",
                operatingHours: "周一至周六 8:00-18:00",
                isOpen: true
            )
        ]
        
        // 初始化显示所有地点
        filteredPlaces = places
    }
    
    // 根据搜索文本筛选地点
    func filterPlaces(by searchText: String) {
        self.searchText = searchText
        applyFilters()
    }
    
    // 应用筛选条件
    func applyFilters() {
        filteredPlaces = places.filter { place in
            // 筛选类别
            let categoryMatch = selectedCategories.contains(place.category)
            
            // 搜索文本筛选
            let searchMatch = searchText.isEmpty || 
                            place.name.localizedCaseInsensitiveContains(searchText) || 
                            place.address.localizedCaseInsensitiveContains(searchText) ||
                            place.category.displayName.localizedCaseInsensitiveContains(searchText)
            
            return categoryMatch && searchMatch
        }
    }
    
    // 重置筛选条件
    func resetFilters() {
        selectedCategories = Set(PlaceCategory.allCases)
        searchText = ""
        applyFilters()
    }
    
    // 放大地图
    func zoomIn() {
        var newRegion = region
        newRegion.span.latitudeDelta /= 2
        newRegion.span.longitudeDelta /= 2
        region = newRegion
    }
    
    // 缩小地图
    func zoomOut() {
        var newRegion = region
        newRegion.span.latitudeDelta *= 2
        newRegion.span.longitudeDelta *= 2
        region = newRegion
    }
    
    // 重置地图区域
    func resetRegion() {
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
}

// 预览
struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
            .environmentObject(CallManager.shared)
    }
} 
