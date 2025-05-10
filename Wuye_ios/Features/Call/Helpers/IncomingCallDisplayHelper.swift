import SwiftUI
import UIKit
import AVFoundation
import linphonesw

// 来电显示辅助类，确保只有一个来电界面
class IncomingCallDisplayHelper {
    static let shared = IncomingCallDisplayHelper()
    
    private var isShowingIncomingCall = false
    private var currentCallViewController: UIViewController?
    
    private init() {}
    
    // 显示来电界面
    func showIncomingCall(caller: String, number: String) {
        DispatchQueue.main.async {
            // 如果已经显示了来电界面，先不显示新的
            if self.isShowingIncomingCall {
                print("[IncomingCallDisplayHelper] 已经有来电界面显示中，忽略新的来电请求")
                return
            }
            
            // 标记为正在显示来电
            self.isShowingIncomingCall = true
            
            // 创建来电视图
            let incomingCallView = IncomingCallView(callerName: caller, callerNumber: number)
                .environmentObject(CallManager.shared)
            
            // 将视图包装为视图控制器
            let hostingController = UIHostingController(rootView: incomingCallView)
            hostingController.modalPresentationStyle = .fullScreen
            
            // 保存引用，用于之后关闭
            self.currentCallViewController = hostingController
            
            // 获取当前的窗口并显示来电界面
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                // 确保在主线程执行UI操作
                print("[IncomingCallDisplayHelper] 显示来电界面")
                rootViewController.present(hostingController, animated: true)
            }
        }
    }
    
    // 关闭来电界面
    func dismissIncomingCall() {
        DispatchQueue.main.async {
            if let viewController = self.currentCallViewController {
                print("[IncomingCallDisplayHelper] 停止显示来电界面")
                viewController.dismiss(animated: true) {
                    self.isShowingIncomingCall = false
                    self.currentCallViewController = nil
                }
            } else {
                self.isShowingIncomingCall = false
            }
        }
    }
}
