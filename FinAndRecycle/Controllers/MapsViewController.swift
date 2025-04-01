//
//  MapsViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 04/03/2025.
//

import UIKit
import MapKit
import FirebaseDatabase


class MapsViewController: UIViewController, MKMapViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    
    @IBOutlet weak var mapView: MKMapView!
        var ref: DatabaseReference! // Firebase Database reference
        var selectedAnnotationTitle: String? // To store the title of the annotation whose callout was tapped
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

                // Ask user for pin title
                let alert = UIAlertController(title: "New Pin", message: "Enter a title", preferredStyle: .alert)
                alert.addTextField()
                let addAction = UIAlertAction(title: "Add Pin", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    let title = alert.textFields?.first?.text ?? "Untitled Pin"
                    // Add pin locally first for immediate feedback
                    self.addPin(coordinate: coordinate, title: title)
                    // Then save to Firebase (without image initially)
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

        // Modified saving function - saves pin metadata, optionally Base64 image data
        // Note: Current flow adds image later, so imageBase64 is usually nil here.
        func savePinToFirebase(coordinate: CLLocationCoordinate2D, title: String, imageBase64: String? = nil) {
            var pinData: [String: Any] = [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "title": title
                // No imageURL key anymore
            ]
            // Add Base64 image data if provided during creation
            if let base64 = imageBase64 {
                // --- WARNING: Storing large strings here! ---
                pinData["imageBase64"] = base64
                print("Including Base64 image data during initial pin save. Monitor DB size/performance.")
            }

            let pinRef = ref.child("pins").childByAutoId()
            pinRef.setValue(pinData) { error, _ in
                if let error = error {
                    print("Error saving pin: \(error.localizedDescription)")
                } else {
                    print("Pin saved successfully with key: \(pinRef.key ?? "N/A")")
                }
            }
        }

        // Function to update an existing pin with Base64 encoded image data
        func saveImageDataToPin(base64String: String) {
            guard let pinTitle = selectedAnnotationTitle else {
                print("Error: Cannot save image data, selectedAnnotationTitle is nil.")
                DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Error", message: "Could not determine which pin to add the image to. Please select the pin again.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(errorAlert, animated: true)
                }
                return
            }

            print("Attempting to save Base64 image data for pin titled: \(pinTitle)")
            print("Base64 String length: \(base64String.count). Storing large strings directly impacts DB performance and cost.")


            findPinByKey(title: pinTitle) { [weak self] (pinKey, pinData) in
                guard let self = self, let key = pinKey else {
                    print("Error: Could not find pin with title '\(pinTitle)' in the database to save image data.")
                    DispatchQueue.main.async {
                       let errorAlert = UIAlertController(title: "Save Error", message: "Could not find the original pin record in the database.", preferredStyle: .alert)
                       errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errorAlert, animated: true)
                    }
                    return
                }

                // Update the specific pin using its unique key, adding/replacing the imageBase64 field
                let updateRef = self.ref.child("pins").child(key)
                // --- WARNING: Updating with potentially large string! ---
                updateRef.updateChildValues(["imageBase64": base64String]) { error, _ in
                    if let error = error {
                        print("Error saving Base64 image data to Database: \(error.localizedDescription)")
                         DispatchQueue.main.async {
                             let errorAlert = UIAlertController(title: "Save Error", message: "Failed to save the image data: \(error.localizedDescription).", preferredStyle: .alert)
                             errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                             self.present(errorAlert, animated: true)
                          }
                    } else {
                        print("Base64 image data successfully saved to pin \(key) in Database!")
                         DispatchQueue.main.async {
                             let successAlert = UIAlertController(title: "Success", message: "Image data saved directly to the pin record. Note potential performance impact.", preferredStyle: .alert)
                             successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                             self.present(successAlert, animated: true)
                         }
                         // TODO: Optionally refresh the specific annotation's callout if visible
                    }
                }
            }
        }


        func showImagePicker() {
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                imagePicker.sourceType = .photoLibrary
                imagePicker.allowsEditing = true // Or false if you prefer original
                present(imagePicker, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Error", message: "Photo Library not available", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }

         func loadPinsFromFirebase() {
            ref.child("pins").observe(.childAdded) { [weak self] snapshot in
                 guard let self = self, let data = snapshot.value as? [String: Any] else { return }
                 if let lat = data["latitude"] as? CLLocationDegrees,
                    let lon = data["longitude"] as? CLLocationDegrees,
                    let title = data["title"] as? String {
                     let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                     // Add pin to map on main thread
                     DispatchQueue.main.async {
                         self.addPin(coordinate: coordinate, title: title)
                     }
                 }
             }
             // Observe changes to potentially update pins if their data (like imageBase64) changes
             ref.child("pins").observe(.childChanged) { [weak self] snapshot in
                 guard let self = self,
                       let data = snapshot.value as? [String: Any],
                       let lat = data["latitude"] as? CLLocationDegrees,
                       let lon = data["longitude"] as? CLLocationDegrees,
                       let title = data["title"] as? String
                 else { return }

                 print("Pin data changed for: \(title)")
                 // If a pin's data changes (e.g., imageBase64 added/updated),
                 // we might need to refresh its annotation view if it's visible or selected.
                 // For simplicity now, the change will be reflected the *next* time
                 // the annotation view or its callout is generated.
                 // Find the annotation on the map with this title
                 if let annotationToUpdate = self.mapView.annotations.first(where: { $0.title == title && !($0 is MKUserLocation) }) {
                      // If the callout is visible for this annotation, maybe redraw it
                      // Or remove/re-add annotation to force refresh (can cause flicker)
                      // Example: Force refresh if selected
                      if self.mapView.selectedAnnotations.contains(where: { $0 === annotationToUpdate }) {
                           DispatchQueue.main.async {
                               self.mapView.deselectAnnotation(annotationToUpdate, animated: false)
                               // A slight delay might be needed before re-selecting to ensure view update
                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                   self.mapView.selectAnnotation(annotationToUpdate, animated: false)
                               }
                           }
                      }
                 }
             }
         }


        //MARK: - MKMapViewDelegate methods

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize the user's location annotation
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
                annotationView.canShowCallout = true // Enable the callout bubble

                // Add the detail disclosure button (the 'i' button)
                let rightButton = UIButton(type: .detailDisclosure)
                annotationView.rightCalloutAccessoryView = rightButton

                // Setup placeholder for the image view
                let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
                imageView.contentMode = .scaleAspectFit
                imageView.image = UIImage(systemName: "photo") // Placeholder image
                annotationView.leftCalloutAccessoryView = imageView // Add image view to the left
            }

            // Load the image for the annotation when the view is prepared
            if let title = annotation.title, let imageView = annotationView.leftCalloutAccessoryView as? UIImageView {
                 // Ensure placeholder is reset before loading
                 imageView.image = UIImage(systemName: "photo") // Start with placeholder
                 // --- Load image data from Base64 string in DB ---
                 loadImageFromBase64(title: title ?? "No Title", imageView: imageView)
            }

            return annotationView
        }

        // Called when the user taps the detail disclosure button ('i') in the annotation callout
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard control == view.rightCalloutAccessoryView else { return } // Ensure it's the right button

            if let annotation = view.annotation, let title = annotation.title {
                // 1. Capture the title of the tapped annotation
                self.selectedAnnotationTitle = title ?? "Untitled Pin" // Store the title

                // 2. Show the details alert (which includes the "Add Image" button)
                print("Tapped callout for: \(self.selectedAnnotationTitle ?? "N/A")")
                showPinDetails(title: self.selectedAnnotationTitle!) // Now showPinDetails can proceed
            } else {
                 print("Could not get annotation title from tapped callout.")
            }
        }


        // Loads the image by decoding Base64 string from Realtime DB
         func loadImageFromBase64(title: String, imageView: UIImageView) {
             findPinByKey(title: title) { pinKey, pinData in
                 guard let data = pinData, let base64String = data["imageBase64"] as? String else {
                     // No image data found for this pin title
                     DispatchQueue.main.async {
                        imageView.image = UIImage(systemName: "photo.fill") // Placeholder showing no image saved
                     }
                     return
                 }

                 // --- Decode Base64 String ---
                 if let decodedData = Data(base64Encoded: base64String) {
                     if let image = UIImage(data: decodedData) {
                         // Successfully decoded and created image
                         DispatchQueue.main.async {
                             imageView.image = image // Set the loaded image
                         }
                     } else {
                         print("Error: Could not create UIImage from decoded Base64 data for pin '\(title)'. Data might be corrupt.")
                          DispatchQueue.main.async {
                             imageView.image = UIImage(systemName: "exclamationmark.triangle.fill") // Indicate corrupt data
                         }
                     }
                 } else {
                     print("Error: Could not decode Base64 string for pin '\(title)'. String might be invalid.")
                      DispatchQueue.main.async {
                         imageView.image = UIImage(systemName: "questionmark.diamond.fill") // Indicate invalid Base64
                     }
                 }
             }
         }

        // Shows the detail alert, loading image from Base64 data if available
        func showPinDetails(title: String) {
             findPinByKey(title: title) { [weak self] pinKey, pinData in
                 guard let self = self else { return }

                 let alert = UIAlertController(title: title, message: "Details for this pin.", preferredStyle: .alert)
                 var imageFound = false

                 if let data = pinData, let base64String = data["imageBase64"] as? String {
                     // Try to decode and display
                     if let decodedData = Data(base64Encoded: base64String), let image = UIImage(data: decodedData) {
                         imageFound = true
                         let imageView = UIImageView(image: image)
                         imageView.contentMode = .scaleAspectFit
                         imageView.translatesAutoresizingMaskIntoConstraints = false // Use constraints

                         alert.view.addSubview(imageView)

                         // Add constraints to position the image view within the alert
                         // Adjust constants as needed for desired layout
                         NSLayoutConstraint.activate([
                            imageView.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
                            imageView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 60), // Space below title
                            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 200), // Max width
                            imageView.heightAnchor.constraint(equalToConstant: 150) // Fixed height
                         ])

                         // Add extra vertical space to the alert to accommodate the image view
                         // Note: This is a bit of a hack; custom view controllers are better for complex layouts.
                         alert.message = "\n\n\n\n\n\n\n\nPin details can go here below the image." // Add enough newlines

                     } else {
                         alert.message = "Could not decode saved image data. Pin details here."
                     }
                 }

                 if !imageFound {
                      alert.message = "No image data saved yet. Pin details here."
                 }


                 // Action to add/update image - triggers the picker flow
                 alert.addAction(UIAlertAction(title: "Add/Change Image", style: .default) { _ in
                     // selectedAnnotationTitle should already be set from callout tap
                     self.showImagePicker() // This will now lead to Base64 encoding/saving
                 })

                 alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                 self.present(alert, animated: true)
             }
         }

        // MARK: - UIImagePickerControllerDelegate methods

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true, completion: nil) // Dismiss picker first

            guard let pickedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else {
                 print("Could not get image from picker.")
                 // Optionally show an alert to the user
                 return
            }

            // Ensure we have a title selected to associate the image with
             guard self.selectedAnnotationTitle != nil else {
                 print("Error: No pin title selected to associate image with.")
                  DispatchQueue.main.async {
                      let errorAlert = UIAlertController(title: "Error", message: "Could not determine which pin to add the image to. Please tap the pin's info button again.", preferredStyle: .alert)
                      errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                      self.present(errorAlert, animated: true)
                  }
                 return
             }

            // --- Convert image to Base64 String ---
            guard let imageData = pickedImage.jpegData(compressionQuality: 0.4) else { // Low quality = smaller data
                print("Could not get JPEG data from image")
                 DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Error", message: "Could not process the selected image.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(errorAlert, animated: true)
                }
                return
            }

            // Check size before encoding (optional but strongly recommended)
            print("Image data size: \(imageData.count) bytes")
            let maxSize = 500_000 // Example: Set a max size in bytes (e.g., 500KB)
            if imageData.count > maxSize {
                print("WARNING: Image data (\(imageData.count / 1024) KB) exceeds limit (\(maxSize / 1024) KB). Encoding and saving may fail or severely impact performance/cost.")
                DispatchQueue.main.async {
                    let sizeAlert = UIAlertController(title: "Image Too Large", message: "The selected image is too large (\(imageData.count / 1024) KB). Please choose a smaller image (under \(maxSize / 1024) KB) or resize it first.", preferredStyle: .alert)
                    sizeAlert.addAction(UIAlertAction(title: "OK", style: .cancel))
                    self.present(sizeAlert, animated: true)
                }
                return // Stop processing if too large
            }

            let base64String = imageData.base64EncodedString()
            print("Base64 String length: \(base64String.count)") // Will be ~33% larger than data size

            // --- Save the Base64 String to the Database ---
            saveImageDataToPin(base64String: base64String)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion: nil)
        }

        // MARK: - Firebase Database Helper

        // Helper function to find a pin's key and data by its title
        // Note: Assumes titles are unique for this to work reliably. Using unique IDs passed around is better.
        func findPinByKey(title: String, completion: @escaping (_ pinKey: String?, _ pinData: [String: Any]?) -> Void) {
            let query = ref.child("pins")
               .queryOrdered(byChild: "title") // Order by title
               .queryEqual(toValue: title)     // Find matching title

             query.observeSingleEvent(of: .value) { snapshot in
                    guard snapshot.exists(), let children = snapshot.children.allObjects as? [DataSnapshot] else {
                         print("No pin found with title: \(title)")
                         completion(nil, nil)
                         return
                     }

                     // If multiple pins have the same title, this takes the first one found.
                     if let firstMatch = children.first {
                         completion(firstMatch.key, firstMatch.value as? [String: Any])
                     } else {
                         // Should not happen if snapshot exists and children is non-empty, but belt-and-suspenders
                         print("Snapshot exists but no children found for title: \(title)")
                         completion(nil, nil)
                     }
             }
        }
    }

