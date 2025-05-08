# 解决SwiftEmitModule编译错误

## 问题描述

在Xcode中构建Swift项目时遇到了以下错误：

```
Command SwiftEmitModule failed with a nonzero exit code
```

这个错误通常表明Swift编译器在生成模块时遇到了问题，可能由于代码语法错误、不兼容的API使用或项目配置问题引起。

## 问题原因分析

经过代码检查，发现问题出在`VerificationCodeView.swift`文件中，主要有以下几个原因：

1. **Swift版本兼容性问题**：
   - Swift 5.9及以上版本的`.onChange`方法采用了新语法：`.onChange(of: value) { oldValue, newValue in ... }`
   - 而旧版本的Swift使用：`.onChange(of: value) { newValue in ... }`
   - 项目编译环境使用的是Swift 6.1，但代码使用了旧语法

2. **依赖管理混乱**：
   - `GRDB.swift`包的导入方式不一致，有的文件使用`import GRDB`，有的文件尝试使用`import GRDBSwift`
   - SPM配置中依赖产品名称与导入不匹配

## 解决方案

### 1. 修复SwiftUI `onChange`方法

在`VerificationCodeView.swift`中添加编译条件，以支持不同版本的Swift：

```swift
#if swift(>=5.9)
.onChange(of: code) { oldValue, newValue in
    processCodeChange(newValue)
}
#else
.onChange(of: code) { newValue in
    processCodeChange(newValue)
}
#endif
```

### 2. 重构代码结构

将验证码处理逻辑抽取为一个单独的方法，减少重复代码：

```swift
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
```

### 3. 统一依赖管理

1. 更新`Package.swift`中GRDB依赖的正确配置：

```swift
.target(
    name: "Wuye_ios",
    dependencies: [
        "Alamofire",
        .product(name: "GRDB", package: "GRDB.swift")
    ]
),
```

2. 统一项目中所有GRDB的导入方式为`import GRDB`：

```swift
import GRDB
```

3. 创建辅助脚本`Scripts/fix_imports.rb`，自动修复所有文件中的导入：

```ruby
#!/usr/bin/env ruby
require 'fileutils'

def process_file(file_path)
  puts "处理文件: #{file_path}"
  
  # 读取文件内容
  content = File.read(file_path)
  
  # 执行替换
  updated_content = content.gsub(/import\s+GRDBSwift/, 'import GRDB')
  
  # 如果有替换，则写回文件
  if content != updated_content
    File.write(file_path, updated_content)
    puts "  - 已更新GRDBSwift导入为GRDB"
    return true
  end
  
  return false
end

# 主处理逻辑
def process_directory(dir)
  updated_files = 0
  
  # 查找所有Swift文件
  Dir.glob("#{dir}/**/*.swift").each do |file|
    if process_file(file)
      updated_files += 1
    end
  end
  
  puts "\n更新完成! 共更新了 #{updated_files} 个文件。"
end

# 指定目录
directory = ARGV[0] || 'Wuye_ios'

puts "开始将Swift文件中的GRDBSwift导入恢复为GRDB..."
process_directory(directory)
```

### 4. 清理构建缓存

清理派生数据可以解决一些顽固的编译问题：

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/Wuye_ios-*
```

## 结果

通过上述修改，成功解决了"Command SwiftEmitModule failed with a nonzero exit code"错误，使项目能够成功编译。

## 预防措施

1. 使用条件编译来处理不同Swift版本的API差异
2. 统一项目中的依赖导入方式
3. 在Package.swift中正确配置依赖关系
4. 定期更新Swift和依赖包版本 