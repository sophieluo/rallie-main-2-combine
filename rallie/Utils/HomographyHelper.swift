import UIKit

class HomographyHelper {
    
    /// Projects a set of known image points to court points — for debugging only
    static func computeHomography(from imagePoints: [CGPoint], to courtPoints: [CGPoint]) -> [CGPoint]? {
        let nsImagePoints = imagePoints.map { NSValue(cgPoint: $0) }
        let nsCourtPoints = courtPoints.map { NSValue(cgPoint: $0) }

        guard let transformed = OpenCVWrapper.computeHomography(from: nsImagePoints, to: nsCourtPoints) else {
            print("❌ Homography computation failed.123")
            return nil
        }

        return transformed.map { $0.cgPointValue }
    }

    /// ✅ New: Compute and return the 3x3 matrix we'll use for projection
    static func computeHomographyMatrix(from imagePoints: [CGPoint], to courtPoints: [CGPoint]) -> [NSNumber]? {
        // Validate input points
        guard imagePoints.count == 8, courtPoints.count == 8 else {
            print("❌ Invalid number of points for homography")
            return nil
        }
        
        print("📐 Computing homography with:")
        print("Image points: \(imagePoints)")
        print("Court points: \(courtPoints)")
        
        let nsImagePoints = imagePoints.map { NSValue(cgPoint: $0) }
        let nsCourtPoints = courtPoints.map { NSValue(cgPoint: $0) }

        guard let matrix = OpenCVWrapper.computeHomography(from: nsImagePoints, to: nsCourtPoints) else {
            print("❌ Homography computation failed")
            return nil
        }
        
        print("✅ Homography matrix computed: \(matrix)")
        return matrix
    }

    // /// ✅ New: Project a single screen point using matrix
    // static func projectsForMap(point: CGPoint, using matrix: [NSNumber], trapezoidCorners: [CGPoint]) -> CGPoint? {
    //     // First check if point is within or very close to trapezoid
    //     guard isPointInTrapezoid(point, corners: trapezoidCorners) else {
    //         print("⚠️ Tap outside trapezoid: \(point)")
    //         return nil
    //     }
        
    //     // Project the raw point coordinates
    //     guard let projected = OpenCVWrapper.projectPoint(point, usingMatrix: matrix) else {
    //         print("❌ Point projection failed for point: \(point)")
    //         return nil
    //     }
        
    //     print("📍 Projected point \(point) to \(projected)")
    //     return projected as! CGPoint
    // }


    /// ✅ New: Project a single screen point using matrix
    static func projectsForMap(point: CGPoint, using matrix: [NSNumber], trapezoidCorners: [CGPoint]) -> CGPoint? {
        // Check if point is within trapezoid but don't return nil if it's not
        let isInsideCourt = isPointInTrapezoid(point, corners: trapezoidCorners)
        
        if !isInsideCourt {
            print("⚠️ Point outside trapezoid: \(point) - attempting projection anyway")
        }
        
        // Project the raw point coordinates regardless of position
        guard let projected = OpenCVWrapper.projectPoint(point, usingMatrix: matrix) else {
            print("❌ Point projection failed for point: \(point)")
            return nil
        }
        
        print("📍 Projected point \(point) to \(projected) - inside court: \(isInsideCourt)")
        return projected as! CGPoint
    }

    static func isPointInTrapezoid(_ point: CGPoint, corners: [CGPoint]) -> Bool {
        // Create a path from the corners
        let path = UIBezierPath()
        path.move(to: corners[0])
        for i in 1...3 {
            path.addLine(to: corners[i])
        }
        path.close()
        
        // Add more tolerance for edge taps
        let tolerance: CGFloat = 20.0  // Increased from 5.0 to be more lenient
        let expandedPath = UIBezierPath(cgPath: path.cgPath)
        expandedPath.lineWidth = tolerance * 2
        
        return expandedPath.contains(point)
    }
}
