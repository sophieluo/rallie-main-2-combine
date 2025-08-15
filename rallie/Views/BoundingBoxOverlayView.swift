//
//  BoundingBoxOverlayView.swift
//  rallie
//
//  Created by Touheed khan on 05/06/2025.
//

import UIKit

class BoundingBoxOverlayView: UIView {

    var boxes: [DetectedObject] = [] {
        didSet {
            DispatchQueue.main.async {
                self.setNeedsDisplay()
            }
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        for box in boxes {
            let convertedRect = convertNormalizedRect(box.rect)

            // Draw green bounding box
            ctx.setLineWidth(2)
            ctx.setStrokeColor(UIColor.red.cgColor)
            ctx.setFillColor(UIColor.red.cgColor)
            ctx.addRect(convertedRect)
            ctx.drawPath(using: .fillStroke)

            // Draw red circle indicator in the center of the bounding box
            let circleRadius: CGFloat = 6
            let center = CGPoint(x: convertedRect.midX, y: convertedRect.midY)
            let circleRect = CGRect(
                x: center.x - circleRadius,
                y: center.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            )

            ctx.setFillColor(UIColor.red.cgColor)
            ctx.fillEllipse(in: circleRect)

            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(2)
            ctx.strokeEllipse(in: circleRect)

            // Draw label above the box
            let label = "\(box.label) \(Int(box.confidence * 100))%"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.white,
                .backgroundColor: UIColor.green.withAlphaComponent(0.7)
            ]
            let textSize = label.size(withAttributes: attributes)
            let labelRect = CGRect(
                x: convertedRect.minX,
                y: convertedRect.minY - textSize.height,
                width: textSize.width + 10,
                height: textSize.height
            )

            // Rounded background for label
            let labelPath = UIBezierPath(roundedRect: labelRect, cornerRadius: 4)
            UIColor.green.withAlphaComponent(0.7).setFill()
            labelPath.fill()

            // Draw text
            let textRect = CGRect(
                x: labelRect.minX + 5,
                y: labelRect.minY,
                width: labelRect.width - 10,
                height: labelRect.height
            )
            label.draw(in: textRect, withAttributes: attributes)
        }
    }

    private func convertNormalizedRect(_ rect: CGRect) -> CGRect {
        // First convert to screen coordinates
        let standardRect = CGRect(
            x: rect.origin.x * bounds.width,
            y: (1 - rect.origin.y - rect.height) * bounds.height,
            width: rect.width * bounds.width,
            height: rect.height * bounds.height
        )
        
        // Then rotate 90 degrees clockwise
        // For 90 degrees clockwise rotation:
        // New x = y
        // New y = width - x - w
        return CGRect(
            x: standardRect.origin.y,
            y: bounds.width - standardRect.origin.x - standardRect.width,
            width: standardRect.height,
            height: standardRect.width
        )
    }
}
