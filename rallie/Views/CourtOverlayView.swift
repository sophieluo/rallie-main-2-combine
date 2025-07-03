//
//  CourtOverlayView.swift
//  rallie
//
//  Created by Xiexiao_Luo on 4/2/25.
//

import SwiftUI

struct CourtOverlayView: View {
    let courtLines: [LineSegment]

    var body: some View {
        Canvas { context, size in
            for segment in courtLines {
                let path = Path { path in
                    path.move(to: segment.start)
                    path.addLine(to: segment.end)
                }
                context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
    
    static func createCourtLines(from points: [CGPoint]) -> [LineSegment] {
        [
            // Main court outline
            LineSegment(start: points[0], end: points[1]), // baseline
            LineSegment(start: points[1], end: points[2]), // right sideline
            LineSegment(start: points[2], end: points[3]), // net line
            LineSegment(start: points[3], end: points[0]), // left sideline
            
            // Service lines
            LineSegment(start: points[4], end: points[5]), // service line
            LineSegment(start: points[6], end: points[7]), // center service line
        ]
    }
}

// Helper structure to represent a line between two points
struct LineSegment {
    let start: CGPoint
    let end: CGPoint
}
