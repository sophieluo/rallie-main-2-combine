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

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        controller.startSession(in: viewController.view, screenSize: UIScreen.main.bounds.size)
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Optional: Update camera layout on rotation if needed
        controller.updatePreviewFrame(to: uiViewController.view.bounds)
    }
}


