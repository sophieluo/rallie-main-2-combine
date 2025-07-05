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

    // Tennis court dimensions in meters
    // Half court is 11.885m long (baseline to net) x 8.23m wide
    // Using coordinate system where (0,0) is at net, Y increases towards baseline
    static let courtWidth: CGFloat = 8.23
    static let courtLength: CGFloat = 11.885
    static let serviceLineDistance: CGFloat = 6.40  // Distance from net to service line
    
    // Calculate additional reference points based on the 5 user-tapped points
    static func calculateAllReferencePoints(from userTappedPoints: [CGPoint]) -> (imagePoints: [CGPoint], courtPoints: [CGPoint])? {
        // Ensure we have exactly 5 user-tapped points
        guard userTappedPoints.count == 5 else {
            print("❌ Need exactly 5 user-tapped points, got \(userTappedPoints.count)")
            return nil
        }
        
        // Extract the user-tapped points with clear naming
        let topLeft = userTappedPoints[0]     // Point 0: Top-left corner (net, left sideline)
        let topRight = userTappedPoints[1]    // Point 1: Top-right corner (net, right sideline)
        let bottomLeft = userTappedPoints[2]  // Point 2: Bottom-left corner (baseline, left sideline)
        let bottomRight = userTappedPoints[3] // Point 3: Bottom-right corner (baseline, right sideline)
        let centerT = userTappedPoints[4]     // Point 4: T-point (center service line intersection)
        
        // Calculate left service line intersection by finding where a horizontal line
        // through the T-point intersects the left sideline
        let leftServiceY = centerT.y
        // Find x by interpolating along the left sideline
        let leftSidelineLength = bottomLeft.y - topLeft.y
        let leftRatio = (leftServiceY - topLeft.y) / leftSidelineLength
        let leftServiceX = topLeft.x + leftRatio * (bottomLeft.x - topLeft.x)
        let leftService = CGPoint(x: leftServiceX, y: leftServiceY)  // Point 5: Left service line intersection
        
        // Calculate right service line intersection by finding where a horizontal line
        // through the T-point intersects the right sideline
        let rightServiceY = centerT.y
        // Find x by interpolating along the right sideline
        let rightSidelineLength = bottomRight.y - topRight.y
        let rightRatio = (rightServiceY - topRight.y) / rightSidelineLength
        let rightServiceX = topRight.x + rightRatio * (bottomRight.x - topRight.x)
        let rightService = CGPoint(x: rightServiceX, y: rightServiceY)  // Point 6: Right service line intersection
        
        // Calculate net center point (middle of net line)
        let netCenterX = (topLeft.x + topRight.x) / 2
        let netCenterY = (topLeft.y + topRight.y) / 2
        let netCenter = CGPoint(x: netCenterX, y: netCenterY)  // Point 7: Center net point
        
        // Assemble all image points (8 total)
        let allImagePoints = [
            // 4 corners (user tapped)
            topLeft,       // Point 0: Top-left corner (net)
            topRight,      // Point 1: Top-right corner (net)
            bottomLeft,    // Point 2: Bottom-left corner (baseline)
            bottomRight,   // Point 3: Bottom-right corner (baseline)
            
            // Service line intersections and center points
            centerT,       // Point 4: T-point (center service)
            leftService,   // Point 5: Left service line intersection
            rightService,  // Point 6: Right service line intersection
            netCenter      // Point 7: Center net point
        ]
        
        // Corresponding court points in meters
        let allCourtPoints = [
            // 4 corners
            CGPoint(x: 0, y: 0),                // Point 0: Top-left corner (net)
            CGPoint(x: courtWidth, y: 0),       // Point 1: Top-right corner (net)
            CGPoint(x: 0, y: courtLength),      // Point 2: Bottom-left corner (baseline)
            CGPoint(x: courtWidth, y: courtLength),  // Point 3: Bottom-right corner (baseline)
            
            // Service line intersections and center points
            CGPoint(x: courtWidth/2, y: serviceLineDistance), // Point 4: T-point (center service)
            CGPoint(x: 0, y: serviceLineDistance),        // Point 5: Left service line intersection
            CGPoint(x: courtWidth, y: serviceLineDistance),// Point 6: Right service line intersection
            CGPoint(x: courtWidth/2, y: 0)      // Point 7: Center net point
        ]
        
        return (allImagePoints, allCourtPoints)
    }

    // Legacy method for backward compatibility
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
            CGPoint(x: bottomInset, y: bottomY),         // Point 0: Bottom-left corner (baseline)
            CGPoint(x: screenSize.width - bottomInset, y: bottomY), // Point 1: Bottom-right corner (baseline)
            CGPoint(x: screenSize.width - topInset, y: topY),  // Point 2: Top-right corner (net)
            CGPoint(x: topInset, y: topY),               // Point 3: Top-left corner (net)
            
            // Service line intersections
            CGPoint(x: leftServiceX, y: serviceLineY),    // Point 4: Left service line intersection
            CGPoint(x: rightServiceX, y: serviceLineY),   // Point 5: Right service line intersection
            CGPoint(x: centerX, y: serviceLineY),         // Point 6: T-point (center service)
            CGPoint(x: centerX, y: topY)                  // Point 7: Center net point
        ]
    }

    // Tennis court dimensions in meters
    // Half court is 11.885m long (baseline to net) x 8.23m wide
    // Using coordinate system where (0,0) is at net, Y increases towards baseline
    static let referenceCourtPoints: [CGPoint] = [
        // Main court corners
        CGPoint(x: 0, y: 0),           // Point 0: Top-left corner (net)
        CGPoint(x: courtWidth, y: 0),   // Point 1: Top-right corner (net)
        CGPoint(x: 0, y: courtLength),  // Point 2: Bottom-left corner (baseline)
        CGPoint(x: courtWidth, y: courtLength),  // Point 3: Bottom-right corner (baseline)
        
        // Service line intersections and center points
        CGPoint(x: courtWidth/2, y: serviceLineDistance), // Point 4: T-point (center service)
        CGPoint(x: 0, y: serviceLineDistance),        // Point 5: Left service line intersection
        CGPoint(x: courtWidth, y: serviceLineDistance),// Point 6: Right service line intersection
        CGPoint(x: courtWidth/2, y: 0)      // Point 7: Center net point
    ]
}
