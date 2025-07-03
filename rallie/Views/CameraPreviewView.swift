//
//  CameraPreviewView.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

import SwiftUI

struct CameraPreviewView: UIViewControllerRepresentable {
    let controller: CameraController

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()

        let screenSize = UIScreen.main.bounds.size
        controller.startSession(in: viewController.view, screenSize: screenSize)

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
