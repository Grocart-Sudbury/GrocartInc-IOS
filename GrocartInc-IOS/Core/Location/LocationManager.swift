//
//  LocationManager.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
import Combine
import CoreLocation

// MARK: - Observable state (no NSObject inheritance — works with MainActor isolation)
@MainActor
final class LocationState: ObservableObject {
    static let shared = LocationState()

    @Published var cityName: String {
        didSet { UserDefaults.standard.set(cityName, forKey: "grocart.selectedCity") }
    }

    private init() {
        // Restore manual city pick if the user previously chose one
        cityName = UserDefaults.standard.string(forKey: "grocart.selectedCity") ?? "Locating..."
    }
}

// MARK: - CLLocation wrapper (NSObject, not ObservableObject)
@MainActor
final class LocationManager: NSObject {

    static let shared = LocationManager()

    private let clManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let state = LocationState.shared

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestLocationIfNeeded() {
        // User already picked a city manually — don't overwrite it
        let saved = UserDefaults.standard.string(forKey: "grocart.selectedCity")
        if let saved, saved != "Locating...", saved != "Location Off" {
            return
        }

        switch clManager.authorizationStatus {
        case .notDetermined:
            clManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            clManager.requestLocation()
        case .denied, .restricted:
            state.cityName = "Location Off"
        @unknown default:
            break
        }
    }

    func resetAndRequestLocation() {
        requestLocationIfNeeded()
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self else { return }
            let city = placemarks?.first?.locality ?? "Unknown Location"
            Task { @MainActor in self.state.cityName = city }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            state.cityName = "Location Off"
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if state.cityName == "Locating..." {
            state.cityName = "Location Off"
        }
    }
}
