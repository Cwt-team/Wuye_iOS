//
//  Wuye_iosApp.swift
//  Wuye_ios
//
//  Created by CUI King on 2025/4/23.
//

import SwiftUI

@main
struct Wuye_iosApp: App {
    var body: some Scene {
        WindowGroup {
            // Wrap 一个 NavigationView，保证 LoginView 里的 NavigationLink 能正常工作
            NavigationView {
                LaunchView()
            }
        }
    }
}
