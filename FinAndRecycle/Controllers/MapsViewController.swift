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


class MapsViewController: UIViewController, MKMapViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var mapView: MKMapView!

        
        var ref: DatabaseReference! // Firebase Database reference
        var storageRef: StorageReference! // Firebase Storage reference
        var selectedCoordinate: CLLocationCoordinate2D?
        
        override func viewDidLoad() {
            super.viewDidLoad()
            mapView.delegate = self
            
            ref = Database.database().reference() // Initialize Firebase Database
            storageRef = Storage.storage().reference() // Initialize Firebase Storage
            
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
                let alert = UIAlertController(title: "New Pin", message: "Enter a title and optionally add a photo", preferredStyle: .alert)
                alert.addTextField()
                let addPhotoAction = UIAlertAction(title: "Add Photo", style: .default) { _ in
                    self.presentImagePicker()
                }
                let addAction = UIAlertAction(title: "Add Pin", style: .default) { _ in
                    let title = alert.textFields?.first?.text ?? "Untitled Pin"
                    self.addPin(coordinate: coordinate, title: title, imageUrl: nil)
                    self.savePinToFirebase(coordinate: coordinate, title: title, imageUrl: nil)
                }
                alert.addAction(addPhotoAction)
                alert.addAction(addAction)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                present(alert, animated: true)
            }
        }
        
        func presentImagePicker() {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            present(imagePicker, animated: true)
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage, let coordinate = selectedCoordinate {
                uploadImage(image, coordinate: coordinate)
            }
            dismiss(animated: true)
        }
        
        func uploadImage(_ image: UIImage, coordinate: CLLocationCoordinate2D) {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            let imageName = UUID().uuidString
            let imageRef = storageRef.child("pins/\(imageName).jpg")
            
            imageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("Error uploading image: \(error.localizedDescription)")
                    return
                }
                
                imageRef.downloadURL { url, error in
                    if let imageUrl = url?.absoluteString {
                        let alert = UIAlertController(title: "Enter Pin Title", message: "Your image is uploaded!", preferredStyle: .alert)
                        alert.addTextField()
                        alert.addAction(UIAlertAction(title: "Add Pin", style: .default) { _ in
                            let title = alert.textFields?.first?.text ?? "Untitled Pin"
                            self.addPin(coordinate: coordinate, title: title, imageUrl: imageUrl)
                            self.savePinToFirebase(coordinate: coordinate, title: title, imageUrl: imageUrl)
                        })
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
        
        func addPin(coordinate: CLLocationCoordinate2D, title: String, imageUrl: String?) {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = title
            mapView.addAnnotation(annotation)
        }
        
        func savePinToFirebase(coordinate: CLLocationCoordinate2D, title: String, imageUrl: String?) {
            var pinData: [String: Any] = [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "title": title
            ]
            
            if let imageUrl = imageUrl {
                pinData["imageUrl"] = imageUrl
            }
            
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
                    let imageUrl = data["imageUrl"] as? String
                    self.addPin(coordinate: coordinate, title: title, imageUrl: imageUrl)
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation else { return }
            let title = annotation.title ?? "Unknown"
            
            ref.child("pins").queryOrdered(byChild: "title").queryEqual(toValue: title).observeSingleEvent(of: .value) { snapshot in
                for child in snapshot.children {
                    if let snap = child as? DataSnapshot, let data = snap.value as? [String: Any], let imageUrl = data["imageUrl"] as? String {
                        if let imageUrl = data["imageUrl"] as? String {
                            self.showPinDetails(title: (title ?? title)!, imageUrl: imageUrl)
                        }                    }
                }
            }
        }
        
        func showPinDetails(title: String, imageUrl: String) {
            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            let imageView = UIImageView(frame: CGRect(x: 10, y: 50, width: 250, height: 250))
            imageView.contentMode = .scaleAspectFill
            
            if let url = URL(string: imageUrl) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data {
                        DispatchQueue.main.async {
                            imageView.image = UIImage(data: data)
                            alert.view.addSubview(imageView)
                        }
                    }
                }.resume()
            }
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
