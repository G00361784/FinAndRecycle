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


        let locationManager = CLLocationManager()
        var currentLocation: CLLocation?
        var pinKeyToVerify: String?
        var pinCoordinatesToVerify: CLLocationCoordinate2D?

        let verificationRadiusInMeters: CLLocationDistance = 50.0


        override func viewDidLoad() {
            super.viewDidLoad()
            mapView.delegate = self
            imagePicker.delegate = self
            ref = Database.database().reference()


            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters


            mapView.showsUserLocation = true


            loadPinsFromFirebase()

            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            mapView.addGestureRecognizer(longPressGesture)
        }


        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            handleAuthorizationStatus(status: manager.authorizationStatus)
        }

        func handleAuthorizationStatus(status: CLAuthorizationStatus) {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                mapView.showsUserLocation = true
                break
            case .denied, .restricted:
                showLocationPermissionAlert()
                mapView.showsUserLocation = false
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            @unknown default:
                 print("Warning: Unhandled CLLocationManager authorization status: \(status)")
            }
        }


        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let latestLocation = locations.last else { return }
            self.currentLocation = latestLocation

            if let key = pinKeyToVerify, let pinCoords = pinCoordinatesToVerify {
                if latestLocation.horizontalAccuracy >= 0 && latestLocation.horizontalAccuracy < 100 {
                    locationManager.stopUpdatingLocation()
                    processProximityVerification(userLocation: latestLocation, pinKey: key, pinCoordinates: pinCoords)
                    self.pinKeyToVerify = nil
                    self.pinCoordinatesToVerify = nil
                } else {
                    // Accuracy not sufficient yet
                }
            }
        }


        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("Location Manager failed with error: \(error.localizedDescription)")
            locationManager.stopUpdatingLocation()
            if pinKeyToVerify != nil {
                 // Potentially show error alert to user if verification was in progress
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


        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            let locationInView = gesture.location(in: mapView)
            let coordinate = mapView.convert(locationInView, toCoordinateFrom: mapView)
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    var pinTitle = "Unknown Location"
                    if let error = error {
                        pinTitle = String(format: "Lat:%.4f, Lon:%.4f", coordinate.latitude, coordinate.longitude)
                    } else if let placemark = placemarks?.first {
                         if let town = placemark.locality, !town.isEmpty { pinTitle = town }
                         else if let area = placemark.subAdministrativeArea, !area.isEmpty { pinTitle = area }
                         else if let name = placemark.name, !name.isEmpty { pinTitle = name }
                         else if let country = placemark.country { pinTitle = "Location in \(country)" }
                    }
                    self.savePinToFirebaseAndAddAnnotation(coordinate: coordinate, title: pinTitle)
                }
            }
        }


        func addPin(coordinate: CLLocationCoordinate2D, title: String, firebaseKey: String, isVerified: Bool) {
            if mapView.annotations.contains(where: { ($0 as? PinAnnotation)?.firebaseKey == firebaseKey }) {
                return
            }
            let annotation = PinAnnotation()
            annotation.coordinate = coordinate
            annotation.title = title
            annotation.firebaseKey = firebaseKey
            annotation.isVerified = isVerified
            mapView.addAnnotation(annotation)
        }

        func savePinToFirebaseAndAddAnnotation(coordinate: CLLocationCoordinate2D, title: String) {
            let pinData: [String: Any] = [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "title": title,
                "isVerified": false
            ]
            let pinRef = ref.child("pins").childByAutoId()
            guard let uniqueKey = pinRef.key else {
                 DispatchQueue.main.async { self.showErrorAlert(message: "Could not save pin.") }
                 return
            }
            pinRef.setValue(pinData) { [weak self] error, _ in
                 guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async { self.showErrorAlert(message: "Failed to save pin.") }
                } else {
                     DispatchQueue.main.async {
                         self.addPin(coordinate: coordinate, title: title, firebaseKey: uniqueKey, isVerified: false)
                     }
                }
            }
        }

        func loadPinsFromFirebase() {
              ref.child("pins").observe(.childAdded, with: { [weak self] snapshot in
                  guard let self = self else { return }
                  self.handlePinData(snapshot: snapshot, isInitialLoad: true)
              })

              ref.child("pins").observe(.childChanged, with: { [weak self] snapshot in
                  guard let self = self else { return }
                  self.handlePinData(snapshot: snapshot, isInitialLoad: false)
              })

              ref.child("pins").observe(.childRemoved, with: { [weak self] snapshot in
                   guard let self = self else { return }
                   let key = snapshot.key
                   if let annotationToRemove = self.mapView.annotations.first(where: { ($0 as? PinAnnotation)?.firebaseKey == key }) {
                       DispatchQueue.main.async {
                           self.mapView.removeAnnotation(annotationToRemove)
                       }
                   }
               })
          }


           func handlePinData(snapshot: DataSnapshot, isInitialLoad: Bool) {
               let key = snapshot.key
               guard let data = snapshot.value as? [String: Any] else {
                   return
               }

               guard let lat = data["latitude"] as? CLLocationDegrees,
                     let lon = data["longitude"] as? CLLocationDegrees,
                     let title = data["title"] as? String else {
                   return
               }
               let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
               let isVerified = data["isVerified"] as? Bool ?? false

               if let existingAnnotation = mapView.annotations.first(where: { ($0 as? PinAnnotation)?.firebaseKey == key }) as? PinAnnotation {
                   var needsViewUpdate = false

                   if existingAnnotation.isVerified != isVerified {
                       existingAnnotation.isVerified = isVerified
                       needsViewUpdate = true
                   }
                   if existingAnnotation.title != title {
                       existingAnnotation.title = title
                       needsViewUpdate = true
                   }

                   if needsViewUpdate {
                       if let view = mapView.view(for: existingAnnotation) as? MKMarkerAnnotationView {
                           updateAnnotationViewAppearance(view, annotation: existingAnnotation)
                       }
                       if data["imageBase64"] != nil {
                           refreshAnnotationViewForKey(key, onlyIfSelected: true)
                       }
                   }

               } else { // Simplified: Add if not existing, regardless of isInitialLoad (safer)
                    DispatchQueue.main.async {
                         self.addPin(coordinate: coordinate, title: title, firebaseKey: key, isVerified: isVerified)
                    }
               }
           }


        func saveImageDataToPin(base64String: String) {
            guard let key = selectedAnnotationKey else { return }

            let updateRef = self.ref.child("pins").child(key)
            updateRef.updateChildValues(["imageBase64": base64String]) { [weak self] error, _ in
                guard let self = self else { return }
                 if error == nil {
                     DispatchQueue.main.async {
                         self.showSuccessAlert(message: "Image saved.")
                         self.refreshAnnotationViewForKey(key, onlyIfSelected: true)
                     }
                 } else {
                     DispatchQueue.main.async {
                         self.showErrorAlert(message: "Failed to save image: \(error!.localizedDescription)")
                     }
                 }
            }
        }

        func loadImageForKey(firebaseKey: String, imageView: UIImageView) {
             imageView.image = UIImage(systemName: "photo")
             imageView.backgroundColor = .systemGray5
             imageView.contentMode = .scaleAspectFill
             imageView.clipsToBounds = true

             ref.child("pins").child(firebaseKey).observeSingleEvent(of: .value) { snapshot in
                 guard let data = snapshot.value as? [String: Any],
                       let base64String = data["imageBase64"] as? String,
                       !base64String.isEmpty else {
                     return
                 }

                 DispatchQueue.global(qos: .userInitiated).async {
                     var decodedImage: UIImage? = nil
                     if let imageData = Data(base64Encoded: base64String) {
                         decodedImage = UIImage(data: imageData)
                     }

                     DispatchQueue.main.async {
                         if let image = decodedImage {
                             imageView.image = image
                             imageView.backgroundColor = .clear
                         } else {
                             imageView.image = UIImage(systemName: "exclamationmark.triangle")
                             imageView.backgroundColor = .systemGray5
                         }
                     }
                 }
             }
        }


        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let pinAnnotation = annotation as? PinAnnotation else { return nil }
            let identifier = "CustomPin"
            var annotationView: MKMarkerAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                annotationView = dequeuedView
                annotationView.annotation = pinAnnotation
            } else {
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
            updateAnnotationViewAppearance(annotationView, annotation: pinAnnotation)
            if let key = pinAnnotation.firebaseKey, let imageView = annotationView.leftCalloutAccessoryView as? UIImageView {
                loadImageForKey(firebaseKey: key, imageView: imageView)
            }
            return annotationView
        }

        func updateAnnotationViewAppearance(_ annotationView: MKMarkerAnnotationView, annotation: PinAnnotation) {
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
                showErrorAlert(message: "Could not identify the selected pin.")
                return
            }

            self.selectedAnnotationKey = key
            self.selectedAnnotationDisplayTitle = pinAnnotation.title ?? "Pin Details"

            showPinDetails(title: self.selectedAnnotationDisplayTitle!, firebaseKey: key, pinCoordinates: pinAnnotation.coordinate)
        }


        func showPinDetails(title: String, firebaseKey: String, pinCoordinates: CLLocationCoordinate2D) {
            ref.child("pins").child(firebaseKey).observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let self = self else { return }

                guard snapshot.exists() else {
                    DispatchQueue.main.async {
                        let errorAlert = UIAlertController(title: "Error", message: "Could not find details for this pin. It might have been deleted.", preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                         if self.view.window != nil {
                             self.present(errorAlert, animated: true)
                         }
                    }
                    return
                }

                let pinData = snapshot.value as? [String: Any]
                let isCurrentlyVerified = pinData?["isVerified"] as? Bool ?? false
                var alertMessage = "Location added."

                if let data = pinData, let base64String = data["imageBase64"] as? String, !base64String.isEmpty {
                     alertMessage = "Image available. Loading..."

                     DispatchQueue.global(qos: .userInitiated).async {
                         var decodedImage: UIImage? = nil
                         if let decodedData = Data(base64Encoded: base64String) {
                             decodedImage = UIImage(data: decodedData)
                         }

                         DispatchQueue.main.async { [weak self] in
                             guard let strongSelf = self else { return }
                             let finalMessage = (decodedImage != nil) ? "Image available." : "Image data found but failed to load."
                             strongSelf.presentPinDetailsAlert(
                                 title: title,
                                 message: finalMessage,
                                 image: decodedImage,
                                 firebaseKey: firebaseKey,
                                 isVerified: isCurrentlyVerified,
                                 pinCoordinates: pinCoordinates
                             )
                         }
                     }
                } else {
                     alertMessage = "No image saved yet."
                     self.presentPinDetailsAlert(
                         title: title,
                         message: alertMessage,
                         image: nil,
                         firebaseKey: firebaseKey,
                         isVerified: isCurrentlyVerified,
                         pinCoordinates: pinCoordinates
                     )
                }
            }
        }


         func presentPinDetailsAlert(title: String, message: String, image: UIImage?, firebaseKey: String, isVerified: Bool, pinCoordinates: CLLocationCoordinate2D) {
              let alert = UIAlertController(title: title, message: message + (isVerified ? "\n(Verified Location)" : "\n(Location Not Verified)"), preferredStyle: .actionSheet)

              // Placeholder for potential future image display IN the alert
              // if let image = image { }

              alert.addAction(UIAlertAction(title: image == nil ? "Add Image" : "Change Image", style: .default) { [weak self] _ in
                   self?.showImagePicker()
              })


              let locationEnabled = CLLocationManager.locationServicesEnabled()
              let authStatus = locationManager.authorizationStatus
              let canVerify = locationEnabled && (authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways)

              let verifyAction = UIAlertAction(title: "Verify Location By Proximity", style: .default) { [weak self] _ in
                  self?.startProximityVerification(forKey: firebaseKey, coordinates: pinCoordinates)
              }
              verifyAction.isEnabled = canVerify
              alert.addAction(verifyAction)
              if !canVerify {
                   alert.message = (alert.message ?? "") + "\n\nEnable Location Services in Settings to verify proximity."
              }


              alert.addAction(UIAlertAction(title: "Delete Pin", style: .destructive) { [weak self] _ in
                  self?.confirmAndDeletePin(forKey: firebaseKey, title: title)
              })

              alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))


              if let popoverController = alert.popoverPresentationController {
                   // Attempt to present from the annotation view if possible
                   var sourceView: UIView = self.view // Fallback
                   var sourceRect: CGRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)

                   if let selectedAnnotation = mapView.annotations.first(where: {($0 as? PinAnnotation)?.firebaseKey == firebaseKey}) {
                       if let annotationView = mapView.view(for: selectedAnnotation) {
                           sourceView = annotationView
                           sourceRect = annotationView.bounds
                       }
                   }
                   popoverController.sourceView = sourceView
                   popoverController.sourceRect = sourceRect
                   popoverController.permittedArrowDirections = [.any] // Allow system to choose best arrow direction
              }

              self.present(alert, animated: true)
          }


           func startProximityVerification(forKey key: String, coordinates: CLLocationCoordinate2D) {
               self.pinKeyToVerify = key
               self.pinCoordinatesToVerify = coordinates
               locationManager.startUpdatingLocation()
               // Consider adding an activity indicator here
           }


           func processProximityVerification(userLocation: CLLocation, pinKey: String, pinCoordinates: CLLocationCoordinate2D) {
               let pinLocation = CLLocation(latitude: pinCoordinates.latitude, longitude: pinCoordinates.longitude)
               let distance = userLocation.distance(from: pinLocation)

               if distance <= verificationRadiusInMeters {
                   updateFirebaseVerification(forKey: pinKey, verified: true) { success in
                       DispatchQueue.main.async {
                           if success {
                               self.showSuccessAlert(message: "Location Verified! You are close enough.")
                           } else {
                               self.showErrorAlert(message: "Could not update verification status.")
                           }
                           // Consider removing activity indicator here
                       }
                   }
               } else {
                   DispatchQueue.main.async {
                       // Consider removing activity indicator here
                       let tooFarAlert = UIAlertController(title: "Verification Failed", message: "You need to be closer (within \(Int(self.verificationRadiusInMeters)) meters) to verify this location. You are currently \(String(format: "%.0f", distance))m away.", preferredStyle: .alert)
                       tooFarAlert.addAction(UIAlertAction(title: "OK", style: .default))
                       self.present(tooFarAlert, animated: true)
                   }
               }
           }


           func updateFirebaseVerification(forKey key: String, verified: Bool, completion: @escaping (Bool) -> Void) {
               ref.child("pins").child(key).updateChildValues(["isVerified": verified]) { [weak self] error, _ in
                   if let error = error {
                       completion(false)
                   } else {
                       self?.updateLocalAnnotationVerification(key: key, newStatus: verified)
                       completion(true)
                   }
               }
           }


           func confirmAndDeletePin(forKey key: String, title: String) {
                let deleteAlert = UIAlertController(title: "Delete Pin?", message: "Are you sure you want to delete the pin at '\(title)'?", preferredStyle: .alert)
                deleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                deleteAlert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                    self?.deletePinFromFirebase(forKey: key)
                })
                self.present(deleteAlert, animated: true)
           }

           func deletePinFromFirebase(forKey key: String) {
                ref.child("pins").child(key).removeValue { [weak self] error, _ in
                     DispatchQueue.main.async {
                         if let error = error {
                             self?.showErrorAlert(message: "Failed to delete pin: \(error.localizedDescription)")
                         } else {
                             // No success alert needed, UI updates via observer
                             // Local annotation removal handled by .childRemoved observer
                         }
                     }
                }
           }


           func updateLocalAnnotationVerification(key: String, newStatus: Bool) {
               if let annotation = mapView.annotations.first(where: { ($0 as? PinAnnotation)?.firebaseKey == key }) as? PinAnnotation {
                   if annotation.isVerified != newStatus {
                       annotation.isVerified = newStatus
                       // Refresh the annotation view appearance immediately
                       if let view = mapView.view(for: annotation) as? MKMarkerAnnotationView {
                           updateAnnotationViewAppearance(view, annotation: annotation)
                       }
                   }
               }
           }


           func showImagePicker() {
               guard selectedAnnotationKey != nil else {
                   showErrorAlert(message: "An error occurred. Please try selecting the pin again.")
                   return
               }

               imagePicker = UIImagePickerController()
               imagePicker.delegate = self
               imagePicker.allowsEditing = false

               let choiceAlert = UIAlertController(title: "Choose Image Source", message: nil, preferredStyle: .actionSheet)

               if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                   choiceAlert.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
                       self?.imagePicker.sourceType = .photoLibrary
                       self?.present(self!.imagePicker, animated: true, completion: nil)
                   })
               }

               if UIImagePickerController.isSourceTypeAvailable(.camera) {
                   choiceAlert.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                       self?.imagePicker.sourceType = .camera
                       self?.present(self!.imagePicker, animated: true, completion: nil)
                   })
               }

               choiceAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

                if let popoverController = choiceAlert.popoverPresentationController {
                    var sourceView: UIView = self.view
                    var sourceRect: CGRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                     if let key = selectedAnnotationKey, let selectedAnnotation = mapView.annotations.first(where: {($0 as? PinAnnotation)?.firebaseKey == key}) {
                         if let annotationView = mapView.view(for: selectedAnnotation) {
                             sourceView = annotationView
                             sourceRect = annotationView.bounds
                         }
                     }
                     popoverController.sourceView = sourceView
                     popoverController.sourceRect = sourceRect
                     popoverController.permittedArrowDirections = [.any]
                }

               self.present(choiceAlert, animated: true)
           }


           func refreshAnnotationViewForKey(_ key: String, onlyIfSelected: Bool = false) {
               guard let annotation = mapView.annotations.first(where: { ($0 as? PinAnnotation)?.firebaseKey == key }) else { return }

               // Check if we only need to refresh if selected AND if it is actually selected
               let isSelected = mapView.selectedAnnotations.contains { $0 === annotation }
               if onlyIfSelected && !isSelected {
                   return
               }

               // Force refresh of the callout if it's the selected one
               if isSelected {
                   mapView.deselectAnnotation(annotation, animated: false)
                   mapView.selectAnnotation(annotation, animated: false) // Re-selecting should trigger viewFor annotation and reload image
               } else {
                   // If not selected, just update the underlying view state (color/glyph)
                    if let view = mapView.view(for: annotation) as? MKMarkerAnnotationView, let pinAnno = annotation as? PinAnnotation {
                        updateAnnotationViewAppearance(view, annotation: pinAnno)
                    }
               }

           }


           func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
               picker.dismiss(animated: true, completion: nil)

               guard let selectedImage = info[.originalImage] as? UIImage else {
                   showErrorAlert(message: "Could not process the selected image.")
                   return
               }

               let targetSize = CGSize(width: 800, height: 800)
               guard let resizedImage = selectedImage.resizeImageTo(size: targetSize) else {
                    showErrorAlert(message: "Could not process the image size.")
                    return
               }

               guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
                   showErrorAlert(message: "Could not convert image format.")
                   return
               }

               let base64String = imageData.base64EncodedString()

               if selectedAnnotationKey != nil {
                   saveImageDataToPin(base64String: base64String)
               } else {
                    showErrorAlert(message: "An error occurred saving the image. Please try again.")
               }
           }

           func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
               picker.dismiss(animated: true, completion: nil)
           }


           func showErrorAlert(message: String) {
               // Ensure presentation on main thread
               DispatchQueue.main.async {
                   guard self.presentedViewController == nil else {
                      // Avoid presenting alert on top of another
                      print("Alert suppressed: Another view controller is already presented.")
                      return
                   }
                   let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                   alert.addAction(UIAlertAction(title: "OK", style: .default))
                   self.present(alert, animated: true)
               }
           }

           func showSuccessAlert(message: String) {
               // Ensure presentation on main thread
               DispatchQueue.main.async {
                    guard self.presentedViewController == nil else {
                       print("Alert suppressed: Another view controller is already presented.")
                       return
                    }
                    let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
           }


       }


    extension UIImage {
        func resizeImageTo(size: CGSize) -> UIImage? {
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            self.draw(in: CGRect(origin: CGPoint.zero, size: size))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return resizedImage
        }
    }
