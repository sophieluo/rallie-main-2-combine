//
//  LandscapeWrapper.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

import SwiftUI
import UIKit

struct LandscapeWrapper<Content: View>: UIViewControllerRepresentable {
    let content: Content
    
    // 初始化器接收一个 SwiftUI View
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIViewController(context: Context) -> LandscapeHostingController<Content> {
        // 创建并返回我们的通用横屏容器，传入 SwiftUI View
        return LandscapeHostingController(rootView: content)
    }
    
    func updateUIViewController(_ uiViewController: LandscapeHostingController<Content>, context: Context) {
        // 如果 SwiftUI View 有更新，需要更新 UIHostingController 的 rootView
        // 注意：直接赋值 rootView 会触发重建，可能不是最高效的，但对于大多数场景足够
        uiViewController.hostingController.rootView = content
    }
}
