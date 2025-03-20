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
    var selectedCoordinate: CLLocationCoordinate2D?
    var selectedAnnotationTitle: String? // To store the title of the selected annotation
    var imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        imagePicker.delegate = self // Set the image picker's delegate
        
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
    func showImagePicker() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            imagePicker.sourceType = .photoLibrary
            imagePicker.allowsEditing = true
            present(imagePicker, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: "Error", message: "Photo Library not available", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
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

            // Add a placeholder for the image
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
            imageView.contentMode = .scaleAspectFit
            annotationView.leftCalloutAccessoryView = imageView
        }

        // Load the image if available
        if let title = annotation.title, let imageView = annotationView.leftCalloutAccessoryView as? UIImageView {
            loadImageForPin(title: title ?? "No Title", imageView: imageView)
        }

        return annotationView
    }

    func loadImageForPin(title: String, imageView: UIImageView) {
        ref.child("pins").observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let pinData = childSnapshot.value as? [String: Any],
                   let pinTitle = pinData["title"] as? String,
                   pinTitle == title,
                   let imageURLString = pinData["imageURL"] as? String,
                   let imageURL = URL(string: imageURLString) {

                    URLSession.shared.dataTask(with: imageURL) { data, _, error in
                        if let data = data, let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                imageView.image = image
                            }
                        } else {
                            print("Error loading image: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }.resume()
                    return
                }
            }
        }
    }

    func showPinDetails(title: String) {
        ref.child("pins").observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let pinData = childSnapshot.value as? [String: Any],
                   let pinTitle = pinData["title"] as? String,
                   pinTitle == title,
                   let imageURLString = pinData["imageURL"] as? String,
                   let imageURL = URL(string: imageURLString),
                   let imageData = try? Data(contentsOf: imageURL),
                   let image = UIImage(data: imageData)
                {
                    let imageView = UIImageView(image: image)
                    imageView.contentMode = .scaleAspectFit
                    imageView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
                    
                    let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
                    alert.view.addSubview(imageView)
                    
                    let heightConstraint = NSLayoutConstraint(item: imageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200)
                    let widthConstraint = NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200)
                    let centerXConstraint = NSLayoutConstraint(item: imageView, attribute: .centerX, relatedBy: .equal, toItem: alert.view, attribute: .centerX, multiplier: 1, constant: 0)
                    let topConstraint = NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal, toItem: alert.view, attribute: .top, multiplier: 1, constant: 60)
                    
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([heightConstraint, widthConstraint, centerXConstraint, topConstraint])
                    
                    alert.addAction(UIAlertAction(title: "Add Image", style: .default) { _ in
                        self.showImagePicker()
                    })
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    return
                } else {
                    let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Add Image", style: .default) { _ in
                        self.showImagePicker()
                    })
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    // MARK: - UIImagePickerControllerDelegate methods
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedImage = info[.editedImage] as? UIImage {
            uploadImageToStorage(image: pickedImage)
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func uploadImageToStorage(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        let storageRef = Storage.storage().reference().child("pin_images/\(UUID().uuidString).jpg")
        
        storageRef.putData(imageData, metadata: nil) { (metadata, error) in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                return
            }
            
            storageRef.downloadURL { (url, error) in
                guard let downloadURL = url, error == nil else {
                    print("Error getting download URL: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                self.saveImageURLToPin(imageURL: downloadURL.absoluteString)
            }
        }
    }
    
    func saveImageURLToPin(imageURL: String) {
        guard let pinTitle = selectedAnnotationTitle else { return }
        
        ref.child("pins").observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let pinData = childSnapshot.value as? [String: Any],
                   let title = pinData["title"] as? String,
                   title == pinTitle {
                    self.ref.child("pins").child(childSnapshot.key).updateChildValues(["imageURL": imageURL]) { error, _ in
                        if let error = error {
                            print("Error saving image URL: \(error.localizedDescription)")
                        } else {
                            print("Image URL saved successfully!")
                        }
                    }
                    return
                }
            }
        }
    }
}
