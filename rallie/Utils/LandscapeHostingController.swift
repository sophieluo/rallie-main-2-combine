//
//  LandscapeHostingController.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

import SwiftUI

class LandscapeHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }

    override var shouldAutorotate: Bool {
        return false
    }
}




