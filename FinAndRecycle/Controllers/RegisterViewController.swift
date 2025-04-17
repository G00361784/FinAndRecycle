//
//  RegisterViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 16/02/2025.
//

import UIKit
import Firebase
import FirebaseDatabase
class RegisterViewController: UIViewController {

    @IBOutlet weak var RegisterEmail: UITextField!
    @IBOutlet weak var RegisterPassword: UITextField!
    
    var ref: DatabaseReference!

       override func viewDidLoad() {
           super.viewDidLoad()
           // Initialize Database reference
           ref = Database.database().reference()
       }

       @IBAction func RegisterPressed(_ sender: UIButton) {
           guard let email = RegisterEmail.text, !email.isEmpty,
                        let password = RegisterPassword.text, !password.isEmpty else {
                      showAlert(title: "Input Missing", message: "Please fill in both email and password.")
                      return
                  }

                  // --- Start: Custom DB Registration (INSECURE) ---
                  ref.child("users").queryOrdered(byChild: "email").queryEqual(toValue: email).observeSingleEvent(of: .value) { [weak self] (snapshot) in
                      guard let self = self else { return }
                      if snapshot.exists() {
                          self.showAlert(title: "Registration Failed", message: "An account with this email already exists.")
                      } else {
                          let newUserRecord: [String: Any] = [
                              "email": email,
                              "password": password, // <-- STORING PASSWORD INSECURELY
                              "createdAt": ServerValue.timestamp(),
                              "score": 0,
                              "rewardsClaimed": false
                          ]
                           let usersRef = self.ref.child("users")
                           let newUserRef = usersRef.childByAutoId() // Creates unique key

                           newUserRef.setValue(newUserRecord) { (error, databaseRef) in
                              DispatchQueue.main.async {
                                  if let error = error {
                                      print("Database write failed: \(error.localizedDescription)")
                                      self.showAlert(title: "Registration Failed", message: "Could not create account. Please try again. \(error.localizedDescription)")
                                  } else {
                                      print("User record created successfully in DB for \(email) with ID \(newUserRef.key ?? "N/A")")
                                      self.showAlert(title: "Registration Successful", message: "Account created!")

                                      // You would need custom logic here to store the logged-in state
                                      // e.g., let loggedInUserID = newUserRef.key
                                      //      UserDefaults.standard.set(loggedInUserID, forKey: "loggedInUserID")

                                      self.performSegue(withIdentifier: "toHomeScreenFromR", sender: self)
                                  }
                              }
                           }
                      }
                  } withCancel: { [weak self] (error) in
                       guard let self = self else { return }
                       print("Database query failed: \(error.localizedDescription)")
                       self.showAlert(title: "Error", message: "Database error: \(error.localizedDescription)")
                  }
                  // --- End: Custom DB Registration (INSECURE) ---
              }

              func showAlert(title: String, message: String) {
                  let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                  alert.addAction(UIAlertAction(title: "OK", style: .default))
                  present(alert, animated: true)
              }
          }
