//
//  MapsViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 04/03/2025.
//

import UIKit
import MapKit
import FirebaseDatabase
import CoreLocation


class PinAnnotation: MKPointAnnotation {
    var firebaseKey: String?
}


class MapsViewController: UIViewController, MKMapViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    
    @IBOutlet weak var mapView: MKMapView!


        var ref: DatabaseReference! // Firebase Database reference
        // Use the unique Firebase Key as the primary identifier for operations
        var selectedAnnotationKey: String?
        // Keep title for display purposes if needed, set alongside the key
        var selectedAnnotationDisplayTitle: String?

        var imagePicker = UIImagePickerController()
        let geocoder = CLGeocoder() // Create a geocoder instance

        // MARK: - Lifecycle Methods
        override func viewDidLoad() {
            super.viewDidLoad()
            mapView.delegate = self
            imagePicker.delegate = self // Set the image picker's delegate

            ref = Database.database().reference() // Initialize Firebase Database

            // Show user location
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow // Or .none if you don't want it to follow initially

            // Load existing pins (using keys) and listen for new ones
            loadPinsFromFirebase()

            // Add Long Press Gesture to Add Pins
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            mapView.addGestureRecognizer(longPressGesture)
        }

        // MARK: - User Actions & Pin Creation

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return } // Only handle the beginning of the press

            let locationInView = gesture.location(in: mapView)
            let coordinate = mapView.convert(locationInView, toCoordinateFrom: mapView)
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            // --- Start Reverse Geocoding ---
            // Consider showing an activity indicator here
            print("Starting reverse geocode...")

            geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
                guard let self = self else { return }

                // Always ensure UI updates happen on the main thread
                DispatchQueue.main.async {
                     // Hide activity indicator here if shown
                     print("Reverse geocode completed.")

                    var pinTitle = "Unknown Location" // Default title

                    if let error = error {
                        print("Reverse geocoding failed with error: \(error.localizedDescription)")
                        pinTitle = String(format: "Lat:%.4f, Lon:%.4f", coordinate.latitude, coordinate.longitude)
                    } else if let placemark = placemarks?.first {
                        // Use locality (town/city in Ireland) or fallback options
                        if let town = placemark.locality, !town.isEmpty {
                            pinTitle = town
                        } else if let area = placemark.subAdministrativeArea, !area.isEmpty { // e.g., County
                            pinTitle = area
                        } else if let name = placemark.name, !name.isEmpty { // Specific place name
                             pinTitle = name
                        } else if let country = placemark.country {
                            pinTitle = "Location in \(country)"
                        }
                        // You could refine further e.g., pinTitle = "\(placemark.name ?? ""), \(placemark.locality ?? "")"
                         print("Placemark details: \(placemark)") // Log details for debugging titles
                    }

                    print("Determined pin title: \(pinTitle)")

                    // Save to Firebase first to get the key, then add annotation to map
                    self.savePinToFirebaseAndAddAnnotation(coordinate: coordinate, title: pinTitle)
                }
            }
        }

        // Adds the visual pin (Annotation) to the map
        func addPin(coordinate: CLLocationCoordinate2D, title: String, firebaseKey: String) {
            // Use the custom PinAnnotation subclass
            let annotation = PinAnnotation()
            annotation.coordinate = coordinate
            annotation.title = title
            annotation.firebaseKey = firebaseKey // Store the unique key!
            mapView.addAnnotation(annotation)
            print("Added annotation to map with key: \(firebaseKey)")
        }

        // MARK: - Firebase Operations

        // Saves initial pin data and then adds the annotation with the generated key
        func savePinToFirebaseAndAddAnnotation(coordinate: CLLocationCoordinate2D, title: String) {
            let pinData: [String: Any] = [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "title": title
                // imageBase64 is added later via update
            ]

            // Generate a unique key locally *before* saving
            let pinRef = ref.child("pins").childByAutoId()
            guard let uniqueKey = pinRef.key else {
                 print("Error: Could not generate unique key for Firebase.")
                 // Show an error alert to the user
                 DispatchQueue.main.async {
                      let errorAlert = UIAlertController(title: "Save Error", message: "Could not generate a unique ID for the new pin. Please try again.", preferredStyle: .alert)
                      errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                      self.present(errorAlert, animated: true)
                 }
                 return
            }

            print("Generated key \(uniqueKey) for pin '\(title)'")

            // Set the value at the reference using the generated key
            pinRef.setValue(pinData) { [weak self] error, _ in
                 guard let self = self else { return }
                if let error = error {
                    print("Error saving initial pin data for key \(uniqueKey): \(error.localizedDescription)")
                    // Show error alert
                    DispatchQueue.main.async {
                         let errorAlert = UIAlertController(title: "Save Error", message: "Failed to save pin data: \(error.localizedDescription).", preferredStyle: .alert)
                         errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                         self.present(errorAlert, animated: true)
                    }
                } else {
                    print("Initial pin data saved successfully for key: \(uniqueKey)")
                    // Now add the annotation to the map on the main thread
                     DispatchQueue.main.async {
                        self.addPin(coordinate: coordinate, title: title, firebaseKey: uniqueKey)
                     }
                }
            }
        }

        // Loads initial pins and listens for new ones being added
         func loadPinsFromFirebase() {
             ref.child("pins").observe(.childAdded) { [weak self] snapshot in
                 guard let self = self else { return }
                 let key = snapshot.key // Get the unique key from the snapshot
                 guard let data = snapshot.value as? [String: Any] else {
                     print("Error: Could not parse data for pin key \(key)")
                     return
                 }

                 if let lat = data["latitude"] as? CLLocationDegrees,
                    let lon = data["longitude"] as? CLLocationDegrees,
                    let title = data["title"] as? String {
                     let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                     // Add pin to map on main thread, using the key
                     DispatchQueue.main.async {
                         print("Loading pin from Firebase: Title='\(title)', Key='\(key)'")
                         self.addPin(coordinate: coordinate, title: title, firebaseKey: key)
                     }
                 } else {
                      print("Error: Missing required data fields (lat, lon, title) for pin key \(key)")
                 }
             }

             // Note: The .childChanged observer previously relied on title matching.
             // If you need real-time updates for images appearing on *other* users' pins,
             // you'd need a more sophisticated approach, perhaps fetching image data again
             // when the annotation view is prepared or selected, or storing annotation views
             // mapped by key to update them directly.
             // Removing the .childChanged observer for simplicity as its previous logic is now invalid.
             // ref.child("pins").removeObserver(withHandle: /* handle from .childChanged observer */)
         }


        // Updates the specific pin record in Firebase with the image data, using the unique key
        func saveImageDataToPin(base64String: String) {
            guard let key = selectedAnnotationKey else {
                print("Error: Cannot save image data, selectedAnnotationKey is nil.")
                DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Error", message: "Could not determine which pin to add the image to. Please tap the pin's info button again.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(errorAlert, animated: true)
                }
                return
            }

            print("Attempting to save Base64 image data for pin key: \(key)")
            print("Base64 String length: \(base64String.count).") // Monitor size

            // Directly update the child node using the unique key
            let updateRef = self.ref.child("pins").child(key)

            // Update only the imageBase64 field
            updateRef.updateChildValues(["imageBase64": base64String]) { [weak self] error, _ in
                 guard let self = self else { return }
                if let error = error {
                    print("Error saving Base64 image data to Database for key \(key): \(error.localizedDescription)")
                      DispatchQueue.main.async {
                         let errorAlert = UIAlertController(title: "Save Error", message: "Failed to save the image data: \(error.localizedDescription).", preferredStyle: .alert)
                         errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                         self.present(errorAlert, animated: true)
                      }
                } else {
                    print("Base64 image data successfully saved to pin key \(key) in Database!")
                      DispatchQueue.main.async {
                         let successAlert = UIAlertController(title: "Success", message: "Image saved.", preferredStyle: .alert)
                         successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                         self.present(successAlert, animated: true)

                         // Optional: Force refresh the callout if it's currently selected
                         self.refreshAnnotationViewForKey(key)
                      }
                }
            }
        }

        // Fetches image data from Firebase using the pin's unique key
        func loadImageForKey(firebaseKey: String, imageView: UIImageView) {
            // Reset to placeholder before loading
            imageView.image = UIImage(systemName: "photo")
            imageView.backgroundColor = .systemGray5 // Indicate loading

            ref.child("pins").child(firebaseKey).observeSingleEvent(of: .value) { snapshot in
                 guard snapshot.exists(), // Make sure the pin record still exists
                       let pinData = snapshot.value as? [String: Any],
                       let base64String = pinData["imageBase64"] as? String,
                       !base64String.isEmpty // Check if image data is actually present
                 else {
                     // No image data found for this pin key or pin doesn't exist
                     print("No imageBase64 found for key \(firebaseKey) or pin deleted.")
                     DispatchQueue.main.async {
                         imageView.image = UIImage(systemName: "photo.fill") // Show placeholder indicating no image
                         imageView.backgroundColor = .clear
                     }
                     return
                 }

                 // --- Decode Base64 String (can be slow, do off main thread) ---
                  DispatchQueue.global(qos: .userInitiated).async {
                     if let decodedData = Data(base64Encoded: base64String) {
                         if let image = UIImage(data: decodedData) {
                             // Successfully decoded and created image
                             DispatchQueue.main.async {
                                 print("Successfully loaded image for key \(firebaseKey)")
                                 imageView.image = image // Set the loaded image
                                 imageView.backgroundColor = .clear
                             }
                         } else {
                             print("Error: Could not create UIImage from decoded Base64 data for key '\(firebaseKey)'. Data might be corrupt.")
                             DispatchQueue.main.async {
                                 imageView.image = UIImage(systemName: "exclamationmark.triangle.fill") // Indicate corrupt data
                                 imageView.backgroundColor = .clear
                             }
                         }
                     } else {
                         print("Error: Could not decode Base64 string for key '\(firebaseKey)'. String might be invalid.")
                         DispatchQueue.main.async {
                             imageView.image = UIImage(systemName: "questionmark.diamond.fill") // Indicate invalid Base64
                             imageView.backgroundColor = .clear
                         }
                     }
                 }
            }
        }

        // MARK: - MapView Delegate Methods

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize the user's blue dot location annotation
            if annotation is MKUserLocation {
                return nil
            }

            // Ensure we are dealing with our custom PinAnnotation to access the key
            guard let pinAnnotation = annotation as? PinAnnotation else {
                 print("Warning: Encountered annotation that is not PinAnnotation type.")
                 // Return nil or a default view if necessary
                 return nil
            }

            let identifier = "CustomPin"
            var annotationView: MKMarkerAnnotationView // Use modern MKMarkerAnnotationView

            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                annotationView = dequeuedView
                annotationView.annotation = pinAnnotation // Update annotation reference
            } else {
                annotationView = MKMarkerAnnotationView(annotation: pinAnnotation, reuseIdentifier: identifier)
                annotationView.canShowCallout = true // Enable the callout bubble

                // Add the detail disclosure button ('i')
                let rightButton = UIButton(type: .detailDisclosure)
                annotationView.rightCalloutAccessoryView = rightButton

                // Setup placeholder for the image view in the callout
                let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)) // Size of the view
                imageView.contentMode = .scaleAspectFill // Fill the square
                imageView.clipsToBounds = true // Clip image to the bounds
                imageView.backgroundColor = .systemGray6 // Background while loading/no image
                imageView.layer.cornerRadius = 4 // Slightly rounded corners for the image view
                annotationView.leftCalloutAccessoryView = imageView
            }

            // --- Load the image using the Firebase Key ---
            if let key = pinAnnotation.firebaseKey, let imageView = annotationView.leftCalloutAccessoryView as? UIImageView {
                // Load image associated with this pin's unique key
                loadImageForKey(firebaseKey: key, imageView: imageView)
            } else {
                 // Handle case where key is somehow nil or view is wrong type
                 if let imageView = annotationView.leftCalloutAccessoryView as? UIImageView {
                      imageView.image = UIImage(systemName: "questionmark.circle.fill") // Error placeholder
                      print("Error: Missing key or imageView for annotation: \(pinAnnotation.title ?? "No Title")")
                 }
            }

            // Customize marker appearance (Optional)
            annotationView.markerTintColor = .systemRed
            annotationView.glyphImage = UIImage(systemName: "mappin.and.ellipse") // Example glyph

            return annotationView
        }

        // Called when the user taps the detail disclosure button ('i') in the annotation callout
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard control == view.rightCalloutAccessoryView else { return } // Ensure it's the right button

            // Get the key from our custom annotation
            guard let pinAnnotation = view.annotation as? PinAnnotation, let key = pinAnnotation.firebaseKey else {
                print("Error: Could not get firebaseKey from tapped annotation view.")
                // Show an error alert?
                 let errorAlert = UIAlertController(title: "Error", message: "Could not identify the selected pin.", preferredStyle: .alert)
                 errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                 present(errorAlert, animated: true)
                return
            }

            // 1. Store the unique key and display title
            self.selectedAnnotationKey = key
            self.selectedAnnotationDisplayTitle = pinAnnotation.title ?? "Pin Details" // Use actual title for display

            print("Tapped callout accessory for pin key: \(key)")

            // 2. Show the details alert, passing the key
            showPinDetails(title: self.selectedAnnotationDisplayTitle!, firebaseKey: key)
        }

        // MARK: - Pin Details & Image Handling

        // Shows the detail alert, fetching data using the unique key
        func showPinDetails(title: String, firebaseKey: String) {
             // Fetch the latest pin data directly using the key
             ref.child("pins").child(firebaseKey).observeSingleEvent(of: .value) { [weak self] snapshot in
                 guard let self = self else { return }

                 guard snapshot.exists() else {
                      print("Error: Pin data for key \(firebaseKey) not found in DB (maybe deleted?).")
                      DispatchQueue.main.async {
                          let errorAlert = UIAlertController(title: "Error", message: "Could not find details for this pin. It might have been deleted.", preferredStyle: .alert)
                          errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                          self.present(errorAlert, animated: true)
                      }
                      return
                 }

                 let pinData = snapshot.value as? [String: Any]
                 let alert = UIAlertController(title: title, message: "Details for this pin.", preferredStyle: .alert)
                 var alertMessage = "Location added." // Base message

                 // --- Attempt to show image preview in alert ---
                 var imageToShow: UIImage? = nil
                 if let data = pinData, let base64String = data["imageBase64"] as? String {
                      // Try to decode image off main thread
                       DispatchQueue.global(qos: .userInitiated).async {
                           var decodedImage: UIImage? = nil
                           if let decodedData = Data(base64Encoded: base64String) {
                                decodedImage = UIImage(data: decodedData)
                           }
                           DispatchQueue.main.async { [weak self] in
                                // Re-check self and build/present the alert now that image decoding is done
                                guard let strongSelf = self else { return }
                                strongSelf.presentPinDetailsAlert(title: title, message: alertMessage, image: decodedImage, firebaseKey: firebaseKey)
                           }
                       }
                       // Don't present the alert yet, wait for the async block above
                       return
                 } else {
                      // No image data found, present alert immediately without image
                      alertMessage = "No image saved for this pin yet."
                      self.presentPinDetailsAlert(title: title, message: alertMessage, image: nil, firebaseKey: firebaseKey)
                 }
             }
         }

        // Helper to build and present the alert after potential async image loading
         func presentPinDetailsAlert(title: String, message: String, image: UIImage?, firebaseKey: String) {
             let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

             if let image = image {
                  // --- Add Image View to Alert (if image loaded successfully) ---
                 // This is still a bit of a hack for UIAlertController. A custom VC is better for complex layouts.
                  let imageSize = CGSize(width: 200, height: 150) // Target display size
                  let imageView = UIImageView(image: image)
                  imageView.contentMode = .scaleAspectFit
                  imageView.translatesAutoresizingMaskIntoConstraints = false

                  // Add a blank line to message for spacing before image
                  alert.message = (alert.message ?? "") + "\n"

                  alert.view.addSubview(imageView)

                  // Constraints need to be relative to alert.view
                  NSLayoutConstraint.activate([
                      imageView.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
                      // Adjust top anchor constant carefully based on alert's internal layout
                      imageView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 70), // May need tweaking
                      imageView.widthAnchor.constraint(lessThanOrEqualToConstant: imageSize.width),
                      imageView.heightAnchor.constraint(equalToConstant: imageSize.height)
                  ])

                 // Add extra space below the image before buttons
                  let spacer = "\n\n\n\n\n\n\n" // Adjust number of lines based on image height
                  alert.message = (alert.message ?? "") + spacer
             }

             // Action to add/update image - triggers the picker flow
             alert.addAction(UIAlertAction(title: image == nil ? "Add Image" : "Change Image", style: .default) { [weak self] _ in
                  // selectedAnnotationKey should already be set from callout tap
                  guard let key = self?.selectedAnnotationKey, key == firebaseKey else {
                       print("Error: Stored key doesn't match key for this alert. Aborting image picker.")
                       // Show error alert
                       return
                  }
                  self?.showImagePicker() // This will use the stored selectedAnnotationKey
             })

             alert.addAction(UIAlertAction(title: "OK", style: .cancel))
             self.present(alert, animated: true)
         }


        // Presents the Image Picker
        func showImagePicker() {
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                imagePicker.sourceType = .photoLibrary
                imagePicker.allowsEditing = true // Allow cropping/editing
                 // imagePicker.mediaTypes = ["public.image"] // Ensure only images can be picked
                present(imagePicker, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Error", message: "Photo Library not available", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }

        // Optional: Helper to refresh an annotation view if its data changes
        func refreshAnnotationViewForKey(_ key: String) {
            // Find the annotation on the map corresponding to this key
            guard let annotationToRefresh = mapView.annotations.first(where: { ($0 as? PinAnnotation)?.firebaseKey == key }) as? PinAnnotation else {
                return // Annotation not found on map
            }

            // If this annotation is currently selected, deselect and reselect it
            // to force the callout to redraw (including the image)
            if mapView.selectedAnnotations.contains(where: { $0 === annotationToRefresh }) {
                print("Refreshing selected annotation view for key \(key)")
                mapView.deselectAnnotation(annotationToRefresh, animated: false)
                // Schedule reselection slightly later to allow UI updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.mapView.selectAnnotation(annotationToRefresh, animated: false)
                }
            }
            // Alternatively, if not selected, find the view and update image directly? More complex.
            // else if let view = mapView.view(for: annotationToRefresh) as? MKMarkerAnnotationView,
            //         let imageView = view.leftCalloutAccessoryView as? UIImageView {
            //      loadImageForKey(firebaseKey: key, imageView: imageView)
            // }
        }


        // MARK: - UIImagePickerControllerDelegate Methods

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true, completion: nil) // Dismiss picker first

            // Prefer edited image, fallback to original
            guard let pickedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else {
                 print("Could not get image from picker.")
                  DispatchQueue.main.async {
                      let errorAlert = UIAlertController(title: "Error", message: "Could not retrieve the selected image.", preferredStyle: .alert)
                      errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                      self.present(errorAlert, animated: true)
                  }
                 return
             }

            // Ensure we have a key selected to associate the image with
             guard self.selectedAnnotationKey != nil else {
                 print("Error: No pin key selected to associate image with.")
                 DispatchQueue.main.async {
                     let errorAlert = UIAlertController(title: "Error", message: "Could not determine which pin to add the image to. Please tap the pin's info button again.", preferredStyle: .alert)
                     errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                     self.present(errorAlert, animated: true)
                 }
                 return
             }

            // --- Convert image to Base64 String ---
            // Use a reasonable compression quality to manage data size
            // 0.4 is quite low, adjust based on quality needs vs data size
            guard let imageData = pickedImage.jpegData(compressionQuality: 0.5) else {
                print("Could not get JPEG data from image")
                 DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Error", message: "Could not process the selected image.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(errorAlert, animated: true)
                 }
                return
            }

            // Check size BEFORE encoding and saving (IMPORTANT for Realtime DB cost/performance)
            print("Image data size: \(imageData.count) bytes (\(imageData.count / 1024) KB)")
            // Set a practical limit for Realtime Database (e.g., < 1MB, ideally much smaller)
            // Firebase Storage is recommended for > ~100KB
            let maxSize = 1_000_000 // 1MB limit example - Adjust as needed!
            if imageData.count > maxSize {
                print("ERROR: Image data (\(imageData.count / 1024) KB) exceeds limit (\(maxSize / 1024) KB).")
                DispatchQueue.main.async {
                    let sizeAlert = UIAlertController(title: "Image Too Large", message: "The selected image is too large (\(imageData.count / 1024) KB). Please choose a smaller image (under \(maxSize / 1024) KB) or use a different storage method.", preferredStyle: .alert)
                    sizeAlert.addAction(UIAlertAction(title: "OK", style: .cancel))
                    self.present(sizeAlert, animated: true)
                }
                return // Stop processing if too large
            }

            let base64String = imageData.base64EncodedString()
            print("Base64 String length: \(base64String.count)") // ~33% larger than data size

            // --- Save the Base64 String to the Database using the selected key ---
            saveImageDataToPin(base64String: base64String)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion: nil)
            print("Image picker cancelled.")
            // Clear selected key if needed, or assume user might tap info button again.
            // self.selectedAnnotationKey = nil
        }

        // MARK: - (REMOVED) Firebase Database Helper
        // The findPinByKey function is no longer needed as we operate directly using the unique key.
        // func findPinByKey(title: String, completion: @escaping (_ pinKey: String?, _ pinData: [String: Any]?) -> Void) { ... }

    } // End of MapsViewController Class
