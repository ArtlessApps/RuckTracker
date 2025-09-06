import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isTracking = false
    
    // Distance tracking
    private var trackingStartLocation: CLLocation?
    private var lastLocation: CLLocation?
    private var totalDistance: Double = 0
    
    // Published distance for the workout
    @Published var distanceTraveled: Double = 0 // in miles
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Only update every 5 meters
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("Location permission not granted")
            return
        }
        
        isTracking = true
        totalDistance = 0
        distanceTraveled = 0
        trackingStartLocation = nil
        lastLocation = nil
        
        locationManager.startUpdatingLocation()
        
        // For watch apps, also request high accuracy
        #if os(watchOS)
        locationManager.requestLocation()
        #endif
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }
    
    func pauseTracking() {
        locationManager.stopUpdatingLocation()
    }
    
    func resumeTracking() {
        guard isTracking else { return }
        locationManager.startUpdatingLocation()
    }
    
    private func updateDistance(to newLocation: CLLocation) {
        guard let lastLoc = lastLocation else {
            // First location update
            lastLocation = newLocation
            trackingStartLocation = newLocation
            return
        }
        
        // Calculate distance from last location
        let distance = lastLoc.distance(from: newLocation)
        
        // Only add if the distance is reasonable (less than 100m per update to filter out GPS errors)
        if distance < 100 && distance > 1 {
            totalDistance += distance
            // Convert from meters to miles
            distanceTraveled = totalDistance * 0.000621371
        }
        
        lastLocation = newLocation
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out old or inaccurate readings
        guard location.timestamp.timeIntervalSinceNow > -5.0,
              location.horizontalAccuracy < 50 else {
            return
        }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            
            if self.isTracking {
                self.updateDistance(to: location)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
