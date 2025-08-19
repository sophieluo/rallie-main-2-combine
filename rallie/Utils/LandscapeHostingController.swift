//
//  LandscapeHostingController.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

import SwiftUI
import UIKit

// MARK: - 1. 通用的横屏容器 UIViewController
// 使用泛型 <Content: View>，表示它可以承载任何 SwiftUI View
class LandscapeHostingController<Content: View>: UIViewController {
    
    var hostingController: UIHostingController<Content>!
    
    // 通过初始化方法接收要展示的 SwiftUI View
    init(rootView: Content) {
        super.init(nibName: nil, bundle: nil)
        // 创建 UIHostingController 时传入传入的 rootView
        self.hostingController = UIHostingController(rootView: rootView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    
    // MARK: - 强制横屏设置
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
         return .landscapeRight // 或者只支持左横屏
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight // 推荐以左横屏展示
    }
    
    override var shouldAutorotate: Bool {
        return false // 如果想锁定在一个方向，返回 false
    }
}
