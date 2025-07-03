import SwiftUI

struct MiniCourtView: View {
    let tappedPoint: CGPoint?           // 🟢 From user tap
    let playerPosition: CGPoint?        // 🎾 From Vision

    let courtWidth: CGFloat = 8.23      // Court width in meters
    let courtHeight: CGFloat = 11.885   // Court height in meters (baseline to net)
    let serviceLineY: CGFloat = 6.40    // Service line distance from net

    var body: some View {
        GeometryReader { geo in
            let scaleX = geo.size.width / courtWidth
            let scaleY = geo.size.height / courtHeight

            ZStack {
                
      //          prevoius Code
                Path { path in
                    // Outer rectangle
                    path.addRect(CGRect(x: 0, y: 0,
                                      width: courtWidth * scaleX,
                                      height: courtHeight * scaleY))

                    // Service line
                    let serviceY = serviceLineY * scaleY
                    path.move(to: CGPoint(x: 0, y: serviceY))
                    path.addLine(to: CGPoint(x: courtWidth * scaleX, y: serviceY))

                    // Center line (from net to service line)
                    let centerX = (courtWidth / 2) * scaleX
                    path.move(to: CGPoint(x: centerX, y: 0))  // Start at net
                    path.addLine(to: CGPoint(x: centerX, y: serviceLineY * scaleY))  // End at service line
                }
                .stroke(Color.white.opacity(0.9), lineWidth: 1)

                // 🟢 Tapped dot
                if let pt = tappedPoint {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .position(x: pt.x * scaleX, y: pt.y * scaleY + 0.8)
                }

                // 🎾 Player position dot
                if let player = playerPosition {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 10, height: 10)
                        .position(x: player.x * scaleX, y: player.y * scaleY + 0.9)
                }
            }
        }
        .aspectRatio(courtWidth / courtHeight, contentMode: .fit)
        .frame(width: 140)
        .padding(.top, 10)
        .padding(.trailing, 10)
    }
}

