//
//  rallieApp.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

class OrientationController: ObservableObject {
    static let shared = OrientationController()
    
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = orientation
        // 强制设备旋转
        forceDeviceOrientation(orientation)
    }
    
    private func forceDeviceOrientation(_ orientation: UIInterfaceOrientationMask) {
        let orientationValue: UIInterfaceOrientation
        
        switch orientation {
        case .landscapeLeft:
            orientationValue = .landscapeLeft
        case .landscapeRight:
            orientationValue = .landscapeRight
        case .portraitUpsideDown:
            orientationValue = .portraitUpsideDown
        default: // .portrait
            orientationValue = .portrait
        }
        
        // iOS 16+ 使用新方法
        if #available(iOS 16.0, *) {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
        // iOS 15 及以下
        else {
            UIDevice.current.setValue(orientationValue.rawValue, forKey: "orientation")
        }
        
//        UIViewController.attemptRotationToDeviceOrientation()
    }
}

@main
struct rallieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    init() {
        // Log OpenCV version on app launch
        OpenCVWrapper.logOpenCVVersion()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
