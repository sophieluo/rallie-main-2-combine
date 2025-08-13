//
//  LandscapeHostingController.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

import SwiftUI
import UIKit

class LandscapeHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeRight
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }

    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        forceLandscapeOrientation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        forceLandscapeOrientation()
        
        // Add notification observer for device rotation
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(orientationChanged), 
                                              name: UIDevice.orientationDidChangeNotification, 
                                              object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Remove notification observer
        NotificationCenter.default.removeObserver(self, 
                                                name: UIDevice.orientationDidChangeNotification, 
                                                object: nil)
    }
    
    private func forceLandscapeOrientation() {
        // Force landscape orientation
        if #available(iOS 16.0, *) {
            // iOS 16+ approach
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        } else {
            // Pre-iOS 16 approach
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        }
    }
    
    @objc private func orientationChanged(_ notification: Notification) {
        // Force back to landscape if device orientation changes
        forceLandscapeOrientation()
    }
}
