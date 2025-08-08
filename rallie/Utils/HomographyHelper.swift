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

    /// Project a single screen point using matrix, with correction for out-of-bounds points
    static func projectsForMap(point: CGPoint, using matrix: [NSNumber], trapezoidCorners: [CGPoint], in: CVPixelBuffer? = nil, screenSize: CGSize? = nil) -> CGPoint? {
        // Check if point is within trapezoid but don't return nil if it's not
        let isInsideCourt = isPointInTrapezoid(point, corners: trapezoidCorners)
        
        // if !isInsideCourt {
        //     print("⚠️ Point outside trapezoid: \(point) - attempting projection anyway")
        // }
        
        // Debug: Print the homography matrix
        // print("🔍 Using homography matrix:")
        // for i in 0..<3 {
        //     print("[\(matrix[i*3].doubleValue), \(matrix[i*3+1].doubleValue), \(matrix[i*3+2].doubleValue)]")
        // }
        
        // Project the raw point coordinates regardless of position
         guard let projected = OpenCVWrapper.projectPoint(point, usingMatrix: matrix) else {
          //   print("❌ Point projection failed for point: \(point)")
             return nil
         }
        
        // Get the raw projected point
        let rawProjected = projected as! CGPoint
        // print("🔄 Raw projected point: \(rawProjected)")
        
        // Tennis court dimensions (in meters)
        let courtWidth: CGFloat = 8.23  // Standard singles court width
        let courtLength: CGFloat = 11.885  // Standard court length (baseline to baseline)
        
        // Apply corrections for extreme values
        var correctedX = rawProjected.x
        var correctedY = rawProjected.y
        
        // X-coordinate correction (keep within reasonable bounds)
        if correctedX < -1.0 || correctedX > courtWidth + 1.0 {
            // Clamp to within 1 meter of court boundaries
            let originalX = correctedX
            correctedX = max(-1.0, min(correctedX, courtWidth + 1.0))
            //print("⚠️ X coordinate clamped: \(originalX) → \(correctedX)")
        }
        
        // Y-coordinate correction (more complex due to common projection issues)
        if correctedY < -1.0 {
            // Point is projected beyond the net (negative Y)
            // Clamp to within 1 meter of net
            let originalY = correctedY
            correctedY = -1.0
            // print("⚠️ Y beyond net clamped: \(originalY) → \(correctedY)")
        } else if correctedY > courtLength + 3.0 {
            // Point is projected far beyond baseline
            // Allow up to 3 meters behind baseline (was 2 meters)
            let originalY = correctedY
            correctedY = courtLength + 3.0
            // print("⚠️ Y far beyond baseline clamped: \(originalY) → \(correctedY)")
        }
        
        let correctedPoint = CGPoint(x: correctedX, y: correctedY)
        
        print("📍 Projected point \(point) to \(rawProjected) - corrected to \(correctedPoint) - inside court: \(isInsideCourt)")
        return correctedPoint
    }

    static func isPointInTrapezoid(_ point: CGPoint, corners: [CGPoint]) -> Bool {
        // Create a path with corners in the correct order to form a proper polygon
        let path = UIBezierPath()
        
        // Start with top-left
        path.move(to: corners[0])
        
        // Go to top-right
        path.addLine(to: corners[1])
        
        // Go to bottom-right (not bottom-left as in the original code)
        path.addLine(to: corners[3])
        
        // Go to bottom-left
        path.addLine(to: corners[2])
        
        path.close()
        
        // Add tolerance for edge taps
        let tolerance: CGFloat = 20.0
        let expandedPath = UIBezierPath(cgPath: path.cgPath)
        expandedPath.lineWidth = tolerance * 2
        
        return expandedPath.contains(point)
    }
}
