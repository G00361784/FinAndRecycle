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
            ref = Database.database().reference()
        }

        @IBAction func RegisterPressed(_ sender: UIButton) {
            guard let email = RegisterEmail.text, !email.isEmpty,
                  let password = RegisterPassword.text, !password.isEmpty else {
                showAlert(title: "Input Missing", message: "Please fill in both email and password.")
                return
            }

            ref.child("users").queryOrdered(byChild: "email").queryEqual(toValue: email).observeSingleEvent(of: .value) { [weak self] (snapshot) in
                guard let self = self else { return }

                if snapshot.exists() {
                    self.showAlert(title: "Registration Failed", message: "An account with this email already exists.")
                } else {
                    let newUserRecord: [String: Any] = [
                        "email": email,
                        "password": password, // <-- WARNING: STORING PASSWORD INSECURELY
                        "createdAt": ServerValue.timestamp(),
                        "score": 0,
                        "rewardsClaimed": true
                    ]

                    let usersRef = self.ref.child("users")
                    let newUserRef = usersRef.childByAutoId()

                    newUserRef.setValue(newUserRecord) { (error, databaseRef) in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("Database write failed: \(error.localizedDescription)")
                                self.showAlert(title: "Registration Failed", message: "Could not create account. Please try again. \(error.localizedDescription)")
                            } else {
                                let newUserID = newUserRef.key ?? "N/A"
                                print("User record created successfully in DB for \(email) with ID \(newUserID)")
                                self.showAlert(title: "Registration Successful", message: "Account created and initial rewards claimed!") {
                                    self.performSegue(withIdentifier: "toHomeScreenFromR", sender: self)
                                }
                            }
                        }
                    }
                }
            } withCancel: { [weak self] (error) in
                guard let self = self else { return }
                print("Database query failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Database error during email check: \(error.localizedDescription)")
                }
            }
        }

        func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completion?()
            })
            present(alert, animated: true)
        }
    }

