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
        
        // Extract the user-tapped points
        let topLeft = userTappedPoints[0]     // Net, left singles sideline
        let topRight = userTappedPoints[1]    // Net, right singles sideline
        let bottomLeft = userTappedPoints[2]  // Baseline, left singles sideline
        let bottomRight = userTappedPoints[3] // Baseline, right singles sideline
        let centerT = userTappedPoints[4]     // T-point (center service line intersection)
        
        // Use the actual y-coordinate from the user-tapped center T-point
        // to ensure the service line passes through the exact point the user tapped
        
        // Calculate left service line intersection by finding where a horizontal line
        // through the center T-point intersects the left sideline
        let leftServiceY = centerT.y
        // Find x by interpolating along the left sideline
        let leftSidelineLength = bottomLeft.y - topLeft.y
        let leftRatio = (leftServiceY - topLeft.y) / leftSidelineLength
        let leftServiceX = topLeft.x + leftRatio * (bottomLeft.x - topLeft.x)
        let leftService = CGPoint(x: leftServiceX, y: leftServiceY)
        
        // Calculate right service line intersection by finding where a horizontal line
        // through the center T-point intersects the right sideline
        let rightServiceY = centerT.y
        // Find x by interpolating along the right sideline
        let rightSidelineLength = bottomRight.y - topRight.y
        let rightRatio = (rightServiceY - topRight.y) / rightSidelineLength
        let rightServiceX = topRight.x + rightRatio * (bottomRight.x - topRight.x)
        let rightService = CGPoint(x: rightServiceX, y: rightServiceY)
        
        // Calculate net center point (middle of net line)
        let netCenterX = (topLeft.x + topRight.x) / 2
        let netCenterY = (topLeft.y + topRight.y) / 2
        let netCenter = CGPoint(x: netCenterX, y: netCenterY)
        
        // Assemble all image points (8 total)
        let allImagePoints = [
            // 4 corners (user tapped)
            topLeft,       // 0: top left (net)
            topRight,      // 1: top right (net)
            bottomLeft,    // 2: bottom left (baseline)
            bottomRight,   // 3: bottom right (baseline)
            
            // Service line intersections
            leftService,   // 4: left service
            rightService,  // 5: right service
            centerT,       // 6: center service (T-point, user tapped)
            netCenter      // 7: net center (calculated)
        ]
        
        // Corresponding court points in meters
        let allCourtPoints = [
            // 4 corners
            CGPoint(x: 0, y: 0),           // 0: top left (net)
            CGPoint(x: courtWidth, y: 0),        // 1: top right (net)
            CGPoint(x: 0, y: courtLength),      // 2: bottom left (baseline)
            CGPoint(x: courtWidth, y: courtLength),   // 3: bottom right (baseline)
            
            // Service line intersections
            CGPoint(x: 0, y: serviceLineDistance),        // 4: left service
            CGPoint(x: courtWidth, y: serviceLineDistance),     // 5: right service
            CGPoint(x: courtWidth/2, y: serviceLineDistance),    // 6: center service (T-point)
            CGPoint(x: courtWidth/2, y: 0)     // 7: net center
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
            CGPoint(x: bottomInset, y: bottomY),         // 0: bottom left
            CGPoint(x: screenSize.width - bottomInset, y: bottomY), // 1: bottom right
            CGPoint(x: screenSize.width - topInset, y: topY),  // 2: top right
            CGPoint(x: topInset, y: topY),               // 3: top left
            
            // Service line intersections
            CGPoint(x: leftServiceX, y: serviceLineY),    // 4: left service
            CGPoint(x: rightServiceX, y: serviceLineY),   // 5: right service
            CGPoint(x: centerX, y: serviceLineY),         // 6: center service
            CGPoint(x: centerX, y: topY)                  // 7: center net
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
        CGPoint(x: 4.115, y: 6.40),    // 6: center service (T-point)
        CGPoint(x: 4.115, y: 0)        // 7: center net
    ]
}
