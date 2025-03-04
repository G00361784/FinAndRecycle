//
//  MapsViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 04/03/2025.
//

import UIKit
import MapKit
import FirebaseDatabase

class MapsViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    var ref: DatabaseReference! // Firebase Database reference

    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        
        ref = Database.database().reference() // Initialize Firebase Database
        
        // Show user location
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        
        // Load existing pins and listen for new ones
        loadPinsFromFirebase()
        
        // Add Tap Gesture to Add Pins
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            
            // Ask user for pin title
            let alert = UIAlertController(title: "New Pin", message: "Enter a title for this location", preferredStyle: .alert)
            alert.addTextField()
            let addAction = UIAlertAction(title: "Add", style: .default) { _ in
                let title = alert.textFields?.first?.text ?? "Untitled Pin"
                self.addPin(coordinate: coordinate, title: title)
                self.savePinToFirebase(coordinate: coordinate, title: title)
            }
            alert.addAction(addAction)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }

        // Adds a pin locally on the map
        func addPin(coordinate: CLLocationCoordinate2D, title: String) {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = title
            mapView.addAnnotation(annotation)
        }
        
        // Saves the pin to Firebase Realtime Database
        func savePinToFirebase(coordinate: CLLocationCoordinate2D, title: String) {
            let pinData: [String: Any] = [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "title": title
            ]
            
            ref.child("pins").childByAutoId().setValue(pinData) { error, _ in
                if let error = error {
                    print("Error saving pin: \(error.localizedDescription)")
                } else {
                    print("Pin saved successfully!")
                }
            }
        }

        // Loads pins from Firebase and listens for live updates
        func loadPinsFromFirebase() {
            ref.child("pins").observe(.childAdded) { snapshot in
                guard let data = snapshot.value as? [String: Any] else { return }
                if let lat = data["latitude"] as? CLLocationDegrees,
                   let lon = data["longitude"] as? CLLocationDegrees,
                   let title = data["title"] as? String {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    self.addPin(coordinate: coordinate, title: title)
                }
            }
        }
    }
