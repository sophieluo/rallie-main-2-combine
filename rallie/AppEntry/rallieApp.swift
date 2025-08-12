//
//  rallieApp.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

import SwiftUI

@main
struct rallieApp: App {
    
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
