# 物业管理系统 iOS 客户端

## 项目简介

物业管理系统iOS客户端是一个为业主提供便捷物业服务的移动应用。本应用支持业主登录、房产信息查看、物业费缴纳、报修工单提交等功能。

## 技术架构

- 开发语言：Swift 5.0+
- 设计模式：MVVM
- 网络框架：Alamofire
- 数据持久化：GRDB
- 响应式编程：Combine
- UI框架：SwiftUI

## 常见问题及解决方案

### 后台线程发布UI更新错误

错误信息：
```
Publishing changes from background threads is not allowed; make sure to publish values from the main thread (via operators like receive(on:)) on model updates.
```

#### 问题原因

SwiftUI的响应式UI框架要求所有与UI绑定的状态更新必须在主线程执行。当在后台线程中更新被`@Published`修饰的属性时，会触发此错误。

#### 解决方案

1. 对于使用Combine的代码，添加`.receive(on: DispatchQueue.main)`操作符：

```swift
apiService.request(...)
    .receive(on: DispatchQueue.main)  // 确保在主线程上接收结果
    .sink { completion in
        // 处理完成
    } receiveValue: { value in
        // 更新状态
        self.somePublishedProperty = value
    }
    .store(in: &cancellables)
```

2. 对于使用回调的代码，使用`DispatchQueue.main.async`：

```swift
apiService.request(...) { [weak self] result in
    DispatchQueue.main.async {
        // 在主线程上更新UI状态
        self?.somePublishedProperty = value
    }
}
```

### 修复位置

以下是项目中常见需要确保主线程更新的位置：

1. **AuthManager.swift**：所有API回调中更新`@Published`属性
2. **LoginViewModel.swift**：处理认证结果和倒计时更新
3. **Repository.swift**：数据库操作完成后的状态更新
4. **APIService.swift**：确保所有API回调在主线程执行

## API测试工具使用说明

API测试工具是一个内置的功能，用于测试与后端的API连接并调试问题。

### 使用步骤

1. 在应用中导航到API测试界面
2. 配置API请求：
   - 输入API终端点（例如：`/mobile/login`）
   - 选择请求方法（GET, POST, PUT, DELETE）
   - 设置是否需要认证
   - 输入请求体JSON（适用于POST/PUT请求）
3. 配置服务器设置：
   - 选择是否使用本地服务器
   - 如果使用本地服务器，可以选择是否使用局域网IP
4. 点击"发送请求"按钮执行API测试
5. 查看响应结果：
   - 状态码
   - 响应内容
   - 错误信息（如果有）

### 错误调试

测试失败时，工具会提供详细的错误信息，包括：

- HTTP状态码
- 错误类型
- 详细错误消息
- 对于常见错误的解决建议
- 线程相关问题的特殊提示

## 开发环境配置

1. Xcode 14.0+
2. iOS 15.0+
3. Swift 5.5+
4. CocoaPods 或 Swift Package Manager

## 构建与运行

1. 克隆仓库
2. 安装依赖：`pod install` 或 `swift package resolve`
3. 打开项目：`open Wuye_ios.xcworkspace`
4. 选择目标设备或模拟器
5. 构建并运行应用

## 项目结构

- `Models/`: 数据模型
- `Views/`: SwiftUI视图
- `ViewModels/`: 视图模型
- `Services/`: 网络服务和API交互
- `Managers/`: 管理认证、配置等
- `Utils/`: 工具类和扩展 