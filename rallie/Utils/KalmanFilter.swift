import Foundation
import UIKit

/// A simple 2D Kalman filter implementation for smoothing player position tracking
class KalmanFilter {
    // State vector [x, y, vx, vy]
    private var x: Double = 0
    private var y: Double = 0
    private var vx: Double = 0
    private var vy: Double = 0
    
    // Covariance matrix (stored as individual elements for simplicity)
    private var p00: Double = 10.0  // x variance
    private var p11: Double = 10.0  // y variance
    private var p22: Double = 10.0  // vx variance
    private var p33: Double = 10.0  // vy variance
    
    // Process noise (how much we expect the state to change randomly)
    private var processNoise: Double = 0.01
    
    // Measurement noise (how noisy our measurements are)
    private var measurementNoise: Double = 1.0
    
    // Last update timestamp
    private var lastUpdateTime: TimeInterval?
    
    /// Initialize a new Kalman filter with default parameters
    /// - Parameters:
    ///   - initialPosition: Initial position estimate (default: origin)
    ///   - initialVelocity: Initial velocity estimate (default: zero)
    ///   - positionUncertainty: Initial uncertainty in position (higher = less confidence)
    ///   - velocityUncertainty: Initial uncertainty in velocity (higher = less confidence)
    ///   - processNoise: Process noise coefficient (how much we expect the state to change randomly)
    ///   - measurementNoise: Measurement noise coefficient (how noisy our measurements are)
    init(initialPosition: CGPoint = .zero,
         initialVelocity: CGVector = .zero,
         positionUncertainty: Double = 10.0,
         velocityUncertainty: Double = 10.0,
         processNoise: Double = 0.01,
         measurementNoise: Double = 1.0) {
        
        // Initial state
        x = Double(initialPosition.x)
        y = Double(initialPosition.y)
        vx = Double(initialVelocity.dx)
        vy = Double(initialVelocity.dy)
        
        // Initial covariance
        p00 = positionUncertainty
        p11 = positionUncertainty
        p22 = velocityUncertainty
        p33 = velocityUncertainty
        
        // Noise parameters
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
    }
    
    /// Update the filter with a new measurement
    /// - Parameters:
    ///   - measurement: New position measurement
    ///   - timestamp: Time of measurement
    /// - Returns: Filtered position estimate
    func update(with measurement: CGPoint, at timestamp: TimeInterval) -> CGPoint {
        let dt = computeDeltaTime(timestamp)
        
        // Prediction step
        predict(dt: dt)
        
        // Correction step
        correct(with: measurement)
        
        // Return the filtered position
        return currentPosition
    }
    
    /// Get the current position estimate without updating
    var currentPosition: CGPoint {
        return CGPoint(x: x, y: y)
    }
    
    /// Get the current velocity estimate
    var currentVelocity: CGVector {
        return CGVector(dx: vx, dy: vy)
    }
    
    // MARK: - Private Methods
    
    private func computeDeltaTime(_ timestamp: TimeInterval) -> Double {
        let dt: Double
        if let lastTime = lastUpdateTime {
            dt = timestamp - lastTime
        } else {
            dt = 1.0 / 30.0 // Assume 30fps if first update
        }
        lastUpdateTime = timestamp
        
        // Clamp dt to reasonable values to avoid instability
        return min(max(dt, 0.01), 0.1)
    }
    
    private func predict(dt: Double) {
        // State prediction
        x = x + vx * dt
        y = y + vy * dt
        // Velocity remains the same in prediction step
        
        // Covariance prediction (simplified)
        // Add process noise to account for uncertainty in the model
        p00 = p00 + dt * dt * p22 + processNoise
        p11 = p11 + dt * dt * p33 + processNoise
        p22 = p22 + processNoise
        p33 = p33 + processNoise
    }
    
    private func correct(with measurement: CGPoint) {
        let measX = Double(measurement.x)
        let measY = Double(measurement.y)
        
        // Innovation (measurement residual)
        let innovationX = measX - x
        let innovationY = measY - y
        
        // Innovation covariance
        let sX = p00 + measurementNoise
        let sY = p11 + measurementNoise
        
        // Kalman gain
        let kX = p00 / sX
        let kY = p11 / sY
        let kVX = p22 * dt / sX
        let kVY = p33 * dt / sY
        
        // State update
        x = x + kX * innovationX
        y = y + kY * innovationY
        vx = vx + kVX * innovationX
        vy = vy + kVY * innovationY
        
        // Covariance update
        p00 = (1 - kX) * p00
        p11 = (1 - kY) * p11
        p22 = (1 - kVX * dt) * p22
        p33 = (1 - kVY * dt) * p33
    }
    
    // Time step for velocity calculations
    private var dt: Double {
        return lastUpdateTime != nil ? 0.033 : 0.033 // ~30fps
    }
}
