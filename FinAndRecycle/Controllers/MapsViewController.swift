//
//  MapsViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 04/03/2025.
//

import UIKit
import MapKit
import FirebaseDatabase
import FirebaseStorage


class MapsViewController: UIViewController, MKMapViewDelegate {


        @IBOutlet weak var mapView: MKMapView!

        var ref: DatabaseReference! // Firebase Database reference
        var selectedCoordinate: CLLocationCoordinate2D?

        override func viewDidLoad() {
            super.viewDidLoad()
            mapView.delegate = self

            ref = Database.database().reference() // Initialize Firebase Database

            // Show user location
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow

            // Load existing pins and listen for new ones
            loadPinsFromFirebase()

            // Add Long Press Gesture to Add Pins
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            mapView.addGestureRecognizer(longPressGesture)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {

            if gesture.state == .began {
                let location = gesture.location(in: mapView)
                let coordinate = mapView.convert(location, toCoordinateFrom: mapView)

                selectedCoordinate = coordinate

                // Ask user for pin title
                let alert = UIAlertController(title: "New Pin", message: "Enter a title", preferredStyle: .alert)
                alert.addTextField()
                let addAction = UIAlertAction(title: "Add Pin", style: .default) { _ in
                    let title = alert.textFields?.first?.text ?? "Untitled Pin"
                    self.addPin(coordinate: coordinate, title: title)
                    self.savePinToFirebase(coordinate: coordinate, title: title)
                }
                alert.addAction(addAction)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                present(alert, animated: true)
            }
        }

        func addPin(coordinate: CLLocationCoordinate2D, title: String) {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = title
            mapView.addAnnotation(annotation)
        }

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

        //MARK: - MKMapViewDelegate methods

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize the user location annotation view
            if annotation is MKUserLocation {
                return nil
            }

            let identifier = "CustomPin"
            var annotationView: MKMarkerAnnotationView

            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                annotationView = dequeuedView
                annotationView.annotation = annotation
            } else {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView.canShowCallout = true // Enable callouts

                // Set up a button for the callout's detail disclosure
                let rightButton = UIButton(type: .detailDisclosure)
                annotationView.rightCalloutAccessoryView = rightButton
            }
            return annotationView
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            // Handle the tap on the callout accessory (detail disclosure button).
            guard let annotation = view.annotation else { return }

            if let title = annotation.title {
                showPinDetails(title: title ?? "No Title")
            }
        }

        func showPinDetails(title: String) {
            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
