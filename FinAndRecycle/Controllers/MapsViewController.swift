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
    var isVerified: Bool = false // Add verification status
}


class MapsViewController: UIViewController, MKMapViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CLLocationManagerDelegate {

    
    @IBOutlet weak var mapView: MKMapView!

    var ref: DatabaseReference!
        var selectedAnnotationKey: String?
        var selectedAnnotationDisplayTitle: String?

        var imagePicker = UIImagePickerController()
        let geocoder = CLGeocoder()

        // --- Core Location Manager ---
        let locationManager = CLLocationManager()
        var currentLocation: CLLocation? // Store the user's latest location
        var pinKeyToVerify: String?      // Temporarily store the key while getting location
        var pinCoordinatesToVerify: CLLocationCoordinate2D? // Store coordinates too

        // Define the verification radius (e.g., 50 meters)
        let verificationRadiusInMeters: CLLocationDistance = 50.0

    // MARK: - Lifecycle Methods
        override func viewDidLoad() {
            super.viewDidLoad()
            mapView.delegate = self
            imagePicker.delegate = self
            ref = Database.database().reference()

            // --- Location Manager Setup ---
            locationManager.delegate = self // << Set the delegate
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters

            // REMOVED: checkLocationAuthorization() << Don't call check directly here

            mapView.showsUserLocation = true // You can still configure the map view
            // Note: showsUserLocation might implicitly trigger the permission request
            // if status is .notDetermined, but relying on the delegate is safer.

            loadPinsFromFirebase()

            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            mapView.addGestureRecognizer(longPressGesture)
        }

    // MARK: - Location Handling

       // --- Delegate method is now the main entry point for authorization ---
       func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
           print("Delegate: locationManagerDidChangeAuthorization called.")
           // Get the current status from the manager passed to the delegate method
           handleAuthorizationStatus(status: manager.authorizationStatus)
       }

       // --- Renamed function to handle the status ---
       func handleAuthorizationStatus(status: CLAuthorizationStatus) {
           switch status {
           case .authorizedWhenInUse, .authorizedAlways:
               print("Location access granted.")
               mapView.showsUserLocation = true // Ensure map shows location dot
               // You could optionally start continuous updates here if needed elsewhere
               // locationManager.startUpdatingLocation()
               break // Proceed

           case .denied, .restricted:
               print("Location access denied or restricted.")
               // Show alert guiding user to Settings
               showLocationPermissionAlert()
               // Potentially disable location-dependent features
               mapView.showsUserLocation = false

           case .notDetermined:
               print("Location status not determined. Requesting When In Use authorization.")
               // Request permission. The delegate method will be called again *after*
               // the user responds to the request dialog.
               locationManager.requestWhenInUseAuthorization()

           @unknown default:
               print("Warning: Unhandled CLLocationManager authorization status: \(status)")
               // Handle unexpected future cases if necessary
           }
       }

       // Delegate method for location updates (no change needed here)
       func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
           // ... (implementation remains the same) ...
           guard let latestLocation = locations.last else { return }
           self.currentLocation = latestLocation

           if let key = pinKeyToVerify, let pinCoords = pinCoordinatesToVerify {
               print("Received location update while waiting to verify pin \(key). Accuracy: \(latestLocation.horizontalAccuracy)m")
               if latestLocation.horizontalAccuracy >= 0 && latestLocation.horizontalAccuracy < 100 {
                   locationManager.stopUpdatingLocation()
                   processProximityVerification(userLocation: latestLocation, pinKey: key, pinCoordinates: pinCoords)
                   self.pinKeyToVerify = nil
                   self.pinCoordinatesToVerify = nil
               } else {
                    print("Location accuracy (\(latestLocation.horizontalAccuracy)m) not sufficient yet.")
               }
           }
       }

       // Delegate method for location errors (no change needed here)
       func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
           // ... (implementation remains the same) ...
            print("Location Manager failed with error: \(error.localizedDescription)")
            locationManager.stopUpdatingLocation() // Stop trying on failure
            if let key = pinKeyToVerify {
                DispatchQueue.main.async { /* Show error alert */ }
                self.pinKeyToVerify = nil
                self.pinCoordinatesToVerify = nil
            }
       }
        func showLocationPermissionAlert() {
             DispatchQueue.main.async {
                 let alert = UIAlertController(title: "Location Permission Needed", message: "To verify pin locations based on proximity, please enable location services for this app in Settings.", preferredStyle: .alert)
                 alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                 alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                     if let url = URL(string: UIApplication.openSettingsURLString) {
                         UIApplication.shared.open(url)
                     }
                 })
                 self.present(alert, animated: true)
             }
         }


        // MARK: - User Actions & Pin Creation (handleLongPress remains the same)
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            let locationInView = gesture.location(in: mapView)
            let coordinate = mapView.convert(locationInView, toCoordinateFrom: mapView)
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            print("Starting reverse geocode...")
            geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    print("Reverse geocode completed.")
                    var pinTitle = "Unknown Location"
                    if let error = error {
                        print("Reverse geocoding failed: \(error.localizedDescription)")
                        pinTitle = String(format: "Lat:%.4f, Lon:%.4f", coordinate.latitude, coordinate.longitude)
                    } else if let placemark = placemarks?.first {
                         if let town = placemark.locality, !town.isEmpty { pinTitle = town }
                         else if let area = placemark.subAdministrativeArea, !area.isEmpty { pinTitle = area }
                         else if let name = placemark.name, !name.isEmpty { pinTitle = name }
                         else if let country = placemark.country { pinTitle = "Location in \(country)" }
                    }
                    print("Determined pin title: \(pinTitle)")
                    self.savePinToFirebaseAndAddAnnotation(coordinate: coordinate, title: pinTitle)
                }
            }
        }
        // addPin remains the same


        // MARK: - Firebase Operations (savePinToFirebaseAndAddAnnotation, loadPinsFromFirebase, saveImageDataToPin, loadImageForKey remain mostly the same)
        // Minor change: Ensure loadPinsFromFirebase handles the observers correctly
        func addPin(coordinate: CLLocationCoordinate2D, title: String, firebaseKey: String, isVerified: Bool) {
            if mapView.annotations.contains(where: { ($0 as? PinAnnotation)?.firebaseKey == firebaseKey }) {
                print("Annotation with key \(firebaseKey) already exists. Skipping add.")
                return
            }
            let annotation = PinAnnotation()
            annotation.coordinate = coordinate
            annotation.title = title
            annotation.firebaseKey = firebaseKey
            annotation.isVerified = isVerified
            mapView.addAnnotation(annotation)
            print("Added annotation to map: Key='\(firebaseKey)', Verified='\(isVerified)'")
        }

        func savePinToFirebaseAndAddAnnotation(coordinate: CLLocationCoordinate2D, title: String) {
            let pinData: [String: Any] = [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "title": title,
                "isVerified": false // Still default to false initially
            ]
            let pinRef = ref.child("pins").childByAutoId()
            guard let uniqueKey = pinRef.key else {
                 print("Error: Could not generate unique key.")
                 DispatchQueue.main.async { self.showErrorAlert(message: "Could not save pin.") }
                 return
            }
            print("Generated key \(uniqueKey) for pin '\(title)'")
            pinRef.setValue(pinData) { [weak self] error, _ in
                 guard let self = self else { return }
                if let error = error {
                    print("Error saving initial pin data for key \(uniqueKey): \(error.localizedDescription)")
                    DispatchQueue.main.async { self.showErrorAlert(message: "Failed to save pin.") }
                } else {
                    print("Initial pin data saved successfully for key: \(uniqueKey)")
                     DispatchQueue.main.async {
                         self.addPin(coordinate: coordinate, title: title, firebaseKey: uniqueKey, isVerified: false)
                     }
                }
            }
        }

        func loadPinsFromFirebase() {
             // Observer for adding new children
             ref.child("pins").observe(.childAdded, with: { [weak self] snapshot in
                 guard let self = self else { return }
                 self.handlePinData(snapshot: snapshot, isInitialLoad: true)
             })

             // Observer for changed children (verification, image, title)
             ref.child("pins").observe(.childChanged, with: { [weak self] snapshot in
                 guard let self = self else { return }
                 self.handlePinData(snapshot: snapshot, isInitialLoad: false) // Handle update
             })

             // Observer for removed children
             ref.child("pins").observe(.childRemoved, with: { [weak self] snapshot in
                  guard let self = self else { return }
                  let key = snapshot.key
                  print("Pin removed notification received for key: \(key)")
                  if let annotationToRemove = self.mapView.annotations.first(where: { ($0 as? PinAnnotation)?.firebaseKey == key }) {
                      DispatchQueue.main.async {
                          print("Removing annotation from map for key: \(key)")
                          self.mapView.removeAnnotation(annotationToRemove)
                      }
                  }
              })
         }

         // Helper to process snapshot data for add/change
         func handlePinData(snapshot: DataSnapshot, isInitialLoad: Bool) {
             let key = snapshot.key
             guard let data = snapshot.value as? [String: Any] else {
                 print("Error parsing data for pin key \(key)")
                 return
             }

             guard let lat = data["latitude"] as? CLLocationDegrees,
                   let lon = data["longitude"] as? CLLocationDegrees,
                   let title = data["title"] as? String else {
                 print("Error: Missing required data fields for pin key \(key)")
                 return
             }
             let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
             let isVerified = data["isVerified"] as? Bool ?? false // Default to false

             // Check if annotation exists
             if let existingAnnotation = mapView.annotations.first(where: { ($0 as? PinAnnotation)?.firebaseKey == key }) as? PinAnnotation {
                 // --- Annotation Exists: Update it ---
                 print("Updating existing annotation for key \(key)")
                 var needsViewUpdate = false

                 // Update verification status if changed
                 if existingAnnotation.isVerified != isVerified {
                     existingAnnotation.isVerified = isVerified
                     print("Verification status changed to \(isVerified) for key \(key)")
                     needsViewUpdate = true
                 }
                 // Update title if changed
                 if existingAnnotation.title != title {
                     existingAnnotation.title = title
                     needsViewUpdate = true // View might update automatically, but let's force refresh if selected
                 }

                 // Trigger visual refresh if needed
                 if needsViewUpdate {
                     if let view = mapView.view(for: existingAnnotation) as? MKMarkerAnnotationView {
                         updateAnnotationViewAppearance(view, annotation: existingAnnotation)
                     }
                     // Refresh callout if image also changed and pin is selected
                     if data["imageBase64"] != nil {
                         refreshAnnotationViewForKey(key, onlyIfSelected: true)
                     }
                 }

             } else if isInitialLoad {
                 // --- Annotation Doesn't Exist & It's Initial Load: Add it ---
                 DispatchQueue.main.async {
                     print("Loading pin from Firebase: Title='\(title)', Key='\(key)', Verified='\(isVerified)'")
                     self.addPin(coordinate: coordinate, title: title, firebaseKey: key, isVerified: isVerified)
                 }
             }
             // If annotation doesn't exist and it's *not* initial load, it means .childAdded event hasn't fired yet or there's an issue. Ignore for now.
         }


        func saveImageDataToPin(base64String: String) {
            // (Implementation remains the same as before)
            guard let key = selectedAnnotationKey else { /*...*/ return }
            let updateRef = self.ref.child("pins").child(key)
            updateRef.updateChildValues(["imageBase64": base64String]) { [weak self] error, _ in
                guard let self = self else { return }
                // (Error/Success handling as before)
                 if error == nil {
                     print("Image data saved successfully for key \(key)")
                     DispatchQueue.main.async {
                         self.showSuccessAlert(message: "Image saved.")
                         self.refreshAnnotationViewForKey(key, onlyIfSelected: true)
                     }
                 } else { /* Show error */ }
            }
        }

        func loadImageForKey(firebaseKey: String, imageView: UIImageView) {
            // (Implementation remains the same as before)
             imageView.image = UIImage(systemName: "photo") // Placeholder
             imageView.backgroundColor = .systemGray5
             ref.child("pins").child(firebaseKey).observeSingleEvent(of: .value) { snapshot in
                // (Decoding logic as before)
             }
        }


        // MARK: - MapView Delegate Methods (viewFor, updateAnnotationViewAppearance, calloutAccessoryControlTapped)

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // (Implementation remains the same, relies on updateAnnotationViewAppearance)
            if annotation is MKUserLocation { return nil }
            guard let pinAnnotation = annotation as? PinAnnotation else { return nil }
            let identifier = "CustomPin"
            var annotationView: MKMarkerAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                annotationView = dequeuedView
                annotationView.annotation = pinAnnotation
            } else {
                // (Setup new view with image view and button as before)
                annotationView = MKMarkerAnnotationView(annotation: pinAnnotation, reuseIdentifier: identifier)
                annotationView.canShowCallout = true
                let rightButton = UIButton(type: .detailDisclosure)
                annotationView.rightCalloutAccessoryView = rightButton
                let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.backgroundColor = .systemGray6
                imageView.layer.cornerRadius = 4
                annotationView.leftCalloutAccessoryView = imageView
            }
            updateAnnotationViewAppearance(annotationView, annotation: pinAnnotation) // Set color/glyph
            if let key = pinAnnotation.firebaseKey, let imageView = annotationView.leftCalloutAccessoryView as? UIImageView {
                loadImageForKey(firebaseKey: key, imageView: imageView) // Load image
            }
            return annotationView
        }

        func updateAnnotationViewAppearance(_ annotationView: MKMarkerAnnotationView, annotation: PinAnnotation) {
            // (Implementation remains the same)
             if annotation.isVerified {
                 annotationView.markerTintColor = .systemGreen
                 annotationView.glyphImage = UIImage(systemName: "checkmark.seal.fill")
             } else {
                 annotationView.markerTintColor = .systemRed
                 annotationView.glyphImage = UIImage(systemName: "mappin.and.ellipse")
             }
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard control == view.rightCalloutAccessoryView else { return }
            guard let pinAnnotation = view.annotation as? PinAnnotation, let key = pinAnnotation.firebaseKey else {
                print("Error: Could not get firebaseKey from tapped annotation view.")
                showErrorAlert(message: "Could not identify the selected pin.")
                return
            }

            self.selectedAnnotationKey = key
            self.selectedAnnotationDisplayTitle = pinAnnotation.title ?? "Pin Details"
            print("Tapped callout accessory for pin key: \(key)")

            // Show details, passing coordinates needed for proximity check later
            showPinDetails(title: self.selectedAnnotationDisplayTitle!, firebaseKey: key, pinCoordinates: pinAnnotation.coordinate)
        }

        // MARK: - Pin Details, Proximity Verification & Image Handling

        // Modified to receive pin coordinates
    func showPinDetails(title: String, firebaseKey: String, pinCoordinates: CLLocationCoordinate2D) {
        // Fetch the latest pin data directly using the key
        ref.child("pins").child(firebaseKey).observeSingleEvent(of: .value) { [weak self] snapshot in
            // Ensure self is still around
            guard let self = self else { return }

            // Ensure the pin data actually exists in Firebase
            guard snapshot.exists() else {
                print("Error: Pin data for key \(firebaseKey) not found in DB (maybe deleted?).")
                DispatchQueue.main.async {
                    // Show an error alert to the user
                    let errorAlert = UIAlertController(title: "Error", message: "Could not find details for this pin. It might have been deleted.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    // Make sure to present the alert if self exists
                     // Check if the view controller is still in the window hierarchy before presenting
                     if self.view.window != nil {
                          self.present(errorAlert, animated: true)
                     }
                }
                return // Stop processing if pin doesn't exist
            }

            // Attempt to parse the data
            let pinData = snapshot.value as? [String: Any]
            // Get verification status, default to false if missing
            let isCurrentlyVerified = pinData?["isVerified"] as? Bool ?? false
            var alertMessage = "Location added." // Base message

            // Check if image data (Base64 string) exists and is not empty
            if let data = pinData, let base64String = data["imageBase64"] as? String, !base64String.isEmpty {
                // Image data exists, attempt to decode it off the main thread
                alertMessage = "Image available. Loading..." // Update message to indicate loading

                DispatchQueue.global(qos: .userInitiated).async {
                    // Variable to hold the result of decoding (optional UIImage)
                    var decodedImage: UIImage? = nil

                    // Attempt to decode the Base64 string into Data
                    if let decodedData = Data(base64Encoded: base64String) {
                        // Attempt to create a UIImage from the decoded Data
                        decodedImage = UIImage(data: decodedData)
                        if decodedImage == nil {
                            // Data was decoded, but couldn't form a valid image
                            print("Error: Could create UIImage from decoded Base64 data for key '\(firebaseKey)'. Data might be corrupt.")
                        }
                    } else {
                        // Base64 string itself was invalid
                        print("Error: Could not decode Base64 string for key '\(firebaseKey)'. String might be invalid.")
                    }

                    // Now, switch back to the main thread to present the alert
                    DispatchQueue.main.async { [weak self] in
                        // Ensure self is still valid after async operation
                        guard let strongSelf = self else { return }

                        // Update the message based on decoding success
                        let finalMessage = (decodedImage != nil) ? "Image available." : "Image data found but failed to load."

                        // Present the alert, passing the decoded image (or nil if decoding failed)
                        strongSelf.presentPinDetailsAlert(
                            title: title,
                            message: finalMessage,
                            image: decodedImage, // Pass the result here
                            firebaseKey: firebaseKey,
                            isVerified: isCurrentlyVerified,
                            pinCoordinates: pinCoordinates
                        )
                    }
                }
                // Since the decoding and presenting is handled in the async block,
                // we don't proceed further in this 'if' branch.
            } else {
                // No image data found in Firebase or it was empty.
                alertMessage = "No image saved yet."

                // Present the alert immediately without an image.
                // We are already on the main thread (Firebase completion handler), so call directly.
                self.presentPinDetailsAlert(
                    title: title,
                    message: alertMessage,
                    image: nil, // Pass nil because there's no image
                    firebaseKey: firebaseKey,
                    isVerified: isCurrentlyVerified,
                    pinCoordinates: pinCoordinates
                )
            }
        } // End of Firebase completion handler
    } // End of showPinDetails function

         // Modified to add "Verify Proximity" and pass coordinates
        func presentPinDetailsAlert(title: String, message: String, image: UIImage?, firebaseKey: String, isVerified: Bool, pinCoordinates: CLLocationCoordinate2D) {
             let alert = UIAlertController(title: title, message: message + (isVerified ? "\n(Verified Location)" : "\n(Location Not Verified)"), preferredStyle: .actionSheet)

             // (Add image action logic remains same)
             if let image = image { /* ... add image action ... */ }

             // (Add/Change image action logic remains same)
             alert.addAction(UIAlertAction(title: image == nil ? "Add Image" : "Change Image", style: .default) { [weak self] _ in
                 /* ... showImagePicker ... */
             })

             // --- Verify Proximity Action ---
             // Only enable if location services are available and authorized
             let locationEnabled = CLLocationManager.locationServicesEnabled()
             let authStatus = locationManager.authorizationStatus
             let canVerify = locationEnabled && (authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways)

             let verifyAction = UIAlertAction(title: "Verify Location By Proximity", style: .default) { [weak self] _ in
                 self?.startProximityVerification(forKey: firebaseKey, coordinates: pinCoordinates)
             }
             verifyAction.isEnabled = canVerify // Disable if location not usable
             alert.addAction(verifyAction)
             if !canVerify {
                  alert.message = (alert.message ?? "") + "\n\nEnable Location Services in Settings to verify proximity."
             }

             // --- Delete Action ---
             alert.addAction(UIAlertAction(title: "Delete Pin", style: .destructive) { [weak self] _ in
                 self?.confirmAndDeletePin(forKey: firebaseKey, title: title)
             })

             alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

             // (Popover presentation logic remains same)
              if let popoverController = alert.popoverPresentationController {
                 /* ... set sourceView/sourceRect ... */
              }

             self.present(alert, animated: true)
         }

        // --- Start Proximity Verification ---
         func startProximityVerification(forKey key: String, coordinates: CLLocationCoordinate2D) {
             print("Starting proximity verification for key \(key)")

             // Store the info needed when location updates arrive
             self.pinKeyToVerify = key
             self.pinCoordinatesToVerify = coordinates

             // Start location updates to get a fresh fix
             locationManager.startUpdatingLocation()

             // Optional: Show an activity indicator to the user
             // Optional: Implement a timeout if location takes too long
         }

         // --- Process Verification Check ---
         func processProximityVerification(userLocation: CLLocation, pinKey: String, pinCoordinates: CLLocationCoordinate2D) {
             let pinLocation = CLLocation(latitude: pinCoordinates.latitude, longitude: pinCoordinates.longitude)
             let distance = userLocation.distance(from: pinLocation) // Distance in meters

             print("Distance to pin \(pinKey): \(distance) meters.")

             if distance <= verificationRadiusInMeters {
                 print("User is within verification radius (\(verificationRadiusInMeters)m). Verifying pin.")
                 // Update Firebase and local annotation
                 updateFirebaseVerification(forKey: pinKey, verified: true) { success in
                     DispatchQueue.main.async {
                         if success {
                             self.showSuccessAlert(message: "Location Verified! You are close enough.")
                         } else {
                             self.showErrorAlert(message: "Could not update verification status.")
                         }
                     }
                 }
             } else {
                 print("User is too far away (\(String(format: "%.1f", distance))m) to verify pin \(pinKey).")
                 DispatchQueue.main.async {
                     let tooFarAlert = UIAlertController(title: "Verification Failed", message: "You need to be closer (within \(Int(self.verificationRadiusInMeters)) meters) to verify this location. You are currently \(String(format: "%.0f", distance))m away.", preferredStyle: .alert)
                     tooFarAlert.addAction(UIAlertAction(title: "OK", style: .default))
                     self.present(tooFarAlert, animated: true)
                 }
             }
         }

         // --- Update Firebase Verification Status ---
         // Modified to include completion handler
         func updateFirebaseVerification(forKey key: String, verified: Bool, completion: @escaping (Bool) -> Void) {
             print("Updating Firebase: Setting isVerified to \(verified) for key \(key)")
             ref.child("pins").child(key).updateChildValues(["isVerified": verified]) { [weak self] error, _ in
                 if let error = error {
                     print("Error updating verification status for key \(key): \(error.localizedDescription)")
                     completion(false) // Indicate failure
                 } else {
                     print("Successfully updated verification status in Firebase for key \(key)")
                     // Update local annotation state immediately (observer might take time)
                     self?.updateLocalAnnotationVerification(key: key, newStatus: verified)
                     completion(true) // Indicate success
                 }
             }
         }


        // (toggleVerificationStatus is replaced by the proximity check logic)

        // (Delete Pin functions confirmAndDeletePin, deletePinFromFirebase remain the same)
         func confirmAndDeletePin(forKey key: String, title: String) { /* ... */ }
         func deletePinFromFirebase(forKey key: String) { /* ... */ }

        // (updateLocalAnnotationVerification remains the same)
         func updateLocalAnnotationVerification(key: String, newStatus: Bool) { /* ... */ }

        // (showImagePicker remains the same)
         func showImagePicker() { /* ... */ }

        // (refreshAnnotationViewForKey remains the same)
         func refreshAnnotationViewForKey(_ key: String, onlyIfSelected: Bool = false) { /* ... */ }

        // (UIImagePickerControllerDelegate methods remain the same)
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) { /* ... */ }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { /* ... */ }

        // --- Helper Alerts ---
        func showErrorAlert(message: String) {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
        func showSuccessAlert(message: String) {
            let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }


    } // End of MapsViewController Class
   // MARK: - UIImage Extension for Resizing (Helper for Action Sheet)
   extension UIImage {
       func resizeImageTo(size: CGSize) -> UIImage? {
           UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
           self.draw(in: CGRect(origin: CGPoint.zero, size: size))
           let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
           UIGraphicsEndImageContext()
           return resizedImage
       }
   }
