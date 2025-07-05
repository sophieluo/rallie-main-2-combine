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
        
        // Get the raw projected point
        let rawProjected = projected as! CGPoint
        
        // Tennis court dimensions (in meters)
        let courtWidth: CGFloat = 8.23  // Standard singles court width
        let courtLength: CGFloat = 11.885  // Standard court length (baseline to baseline)
        
        // Apply corrections for extreme values
        var correctedX = rawProjected.x
        var correctedY = rawProjected.y
        
        // X-coordinate correction (keep within reasonable bounds)
        if correctedX < -1.0 || correctedX > courtWidth + 1.0 {
            // Clamp to within 1 meter of court boundaries
            correctedX = max(-1.0, min(correctedX, courtWidth + 1.0))
            print("⚠️ X coordinate clamped: \(rawProjected.x) → \(correctedX)")
        }
        
        // Y-coordinate correction (more complex due to common projection issues)
        if correctedY < -1.0 {
            // Point is projected beyond the net (negative Y)
            // Clamp to within 1 meter of net
            correctedY = -1.0
            print("⚠️ Y beyond net clamped: \(rawProjected.y) → \(correctedY)")
        } else if correctedY > courtLength + 1.0 {
            // Point is projected beyond baseline
            
            // For extreme values like 19.623144149780273, apply special handling
            if correctedY > courtLength * 1.5 {
                // For values more than 50% beyond court length, place just beyond baseline
                correctedY = courtLength + 1.0
                print("🚨 Extreme Y value corrected: \(rawProjected.y) → \(correctedY)")
            } else {
                // For less extreme values, clamp to within 1 meter of baseline
                correctedY = courtLength + 1.0
                print("⚠️ Y beyond baseline clamped: \(rawProjected.y) → \(correctedY)")
            }
        }
        
        let correctedPoint = CGPoint(x: correctedX, y: correctedY)
        
        print("📍 Projected point \(point) to \(rawProjected) - corrected to \(correctedPoint) - inside court: \(isInsideCourt)")
        return correctedPoint
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
