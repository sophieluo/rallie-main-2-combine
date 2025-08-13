//
//  CameraPreviewControllerWrapper.swift
//  rallie
//
//  Created by Xiexiao_Luo on 4/2/25.
//

import SwiftUI
import UIKit

struct CameraPreviewControllerWrapper: UIViewControllerRepresentable {
    let controller: CameraController

    class Coordinator: NSObject {
        var controller: CameraController
        var parent: CameraPreviewControllerWrapper
        
        init(controller: CameraController, parent: CameraPreviewControllerWrapper) {
            self.controller = controller
            self.parent = parent
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        // Use the full screen size for the camera preview
        let screenSize = UIScreen.main.bounds.size
        // Swap width and height for landscape orientation
        let landscapeSize = CGSize(width: max(screenSize.width, screenSize.height), 
                                  height: min(screenSize.width, screenSize.height))
        
        // Start session here since we removed it from CameraView.onAppear
        controller.startSession(in: viewController.view, screenSize: landscapeSize)
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update camera layout to fill the entire view
        controller.updatePreviewFrame(to: uiViewController.view.bounds)
        
        // Ensure the preview layer is attached to the view
        DispatchQueue.main.async {
            if controller.previewLayer?.superlayer == nil {
                if let previewLayer = controller.previewLayer {
                    uiViewController.view.layer.insertSublayer(previewLayer, at: 0)
                    print(" Re-attached preview layer to view")
                } else {
                    print(" Preview layer is nil during update")
                }
            }
        }
    }
}
