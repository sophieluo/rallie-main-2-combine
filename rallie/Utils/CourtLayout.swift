//
//  CourtLayout.swift
//  rallie
//
//  Created by Xiexiao_Luo on 3/29/25.
//

// MARK: - CourtLayout.swift
import CoreGraphics

struct CourtLayout {
    static let screenWidth: CGFloat = 844   // landscape iPhone 13
    static let screenHeight: CGFloat = 390

    static func referenceImagePoints(for screenSize: CGSize) -> [CGPoint] {
        let topY = screenSize.height * 0.45  
        let bottomY = screenSize.height * 0.88
        let topInset = screenSize.width * 0.35  
        let bottomInset = screenSize.width * 0.05  
        
        // Calculate service line Y position (between top and bottom)
        let serviceLineY = topY + (bottomY - topY) * 0.35  
        
        // Calculate service line intersections using the sideline equations
        let leftX1 = bottomInset  // bottom left X
        let leftX2 = topInset    // top left X
        let leftY1 = bottomY     // bottom Y
        let leftY2 = topY        // top Y
        
        let rightX1 = screenSize.width - bottomInset  // bottom right X
        let rightX2 = screenSize.width - topInset     // top right X
        let rightY1 = bottomY                    // bottom Y
        let rightY2 = topY                       // top Y
        
        // Calculate X coordinates where service line intersects sidelines
        let leftServiceX = leftX1 + (leftX2 - leftX1) * ((serviceLineY - leftY1) / (leftY2 - leftY1))
        let rightServiceX = rightX1 + (rightX2 - rightX1) * ((serviceLineY - rightY1) / (rightY2 - rightY1))
        
        // Center line X position (average of service line endpoints)
        let centerX = (leftServiceX + rightServiceX) / 2
        
        return [
            // Main court corners
            CGPoint(x: bottomInset, y: bottomY),         // 0: bottom left
            CGPoint(x: screenSize.width - bottomInset, y: bottomY), // 1: bottom right
            CGPoint(x: screenSize.width - topInset, y: topY),  // 2: top right
            CGPoint(x: topInset, y: topY),               // 3: top left
            
            // Service line intersections
            CGPoint(x: leftServiceX, y: serviceLineY),    // 4: left service
            CGPoint(x: rightServiceX, y: serviceLineY),   // 5: right service
            CGPoint(x: centerX, y: serviceLineY),         // 6: center service
            CGPoint(x: centerX, y: serviceLineY)          // 7: center service (duplicate)
        ]
    }

    // Tennis court dimensions in meters
    // Half court is 11.885m long (baseline to net) x 8.23m wide
    // Using coordinate system where (0,0) is at net, Y increases towards baseline
    static let referenceCourtPoints: [CGPoint] = [
        // Main court corners
        CGPoint(x: 0, y: 11.885),      // 0: bottom left (baseline)
        CGPoint(x: 8.23, y: 11.885),   // 1: bottom right (baseline)
        CGPoint(x: 8.23, y: 0),        // 2: top right (net)
        CGPoint(x: 0, y: 0),           // 3: top left (net)
        
        // Service line intersections (6.40m from net)
        CGPoint(x: 0, y: 6.40),        // 4: left service
        CGPoint(x: 8.23, y: 6.40),     // 5: right service
        CGPoint(x: 4.115, y: 6.40),    // 6: center service (back)
        CGPoint(x: 4.115, y: 6.40)     // 7: center service (at service line)
    ]
}

