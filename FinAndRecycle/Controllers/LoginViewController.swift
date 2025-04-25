//
//  LoginViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 10/02/2025.
//
import UIKit
import FirebaseCore
import FirebaseDatabase
class LoginViewController: UIViewController {

    
    @IBOutlet weak var LoginEmail: UITextField!
    
    @IBOutlet weak var LoginPassword: UITextField!

        // --- Database Reference ---
        var ref: DatabaseReference!

    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
        print("Firebase Database reference initialized.")
        setupKeyboardDismissal()
    }


        @IBAction func loginPressed(_ sender: UIButton) {

             
           
                    guard let email = LoginEmail.text?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
                        showAlert(title: "Email Missing", message: "Please enter your email address.")
                        return
                    }
                    guard let password = LoginPassword.text, !password.isEmpty else {
                        showAlert(title: "Password Missing", message: "Please enter your password.")
                        return
                    }

                    print("Attempting login for email: \(email)")

                    ref.child("users")
                        .queryOrdered(byChild: "email")
                        .queryEqual(toValue: email)
                        .observeSingleEvent(of: .value) { [weak self] (snapshot) in

                        guard let self = self else { return }
                        print("Firebase snapshot value for email query: \(snapshot.value ?? "nil")")

                        guard snapshot.exists() else {
                            print("No user found matching email: \(email)")
                            self.showAlert(title: "Login Failed", message: "Invalid email or password.")
                            return
                        }

                        guard let usersData = snapshot.value as? [String: [String: Any]] else {
                            print("Error: Could not parse snapshot value into expected format [String: [String: Any]] for email: \(email)")
                            self.showAlert(title: "Login Error", message: "Could not process user data. Please check data structure.")
                            return
                        }

                        guard usersData.count == 1, let userEntry = usersData.first else {
                            print("Error: Expected 1 user for email \(email), found \(usersData.count). Or failed to get user data.")
                            self.showAlert(title: "Login Failed", message: "An account error occurred.")
                            return
                        }

                        let userID = userEntry.key // Get the unique ID for this user
                        let userDataDictionary = userEntry.value

                        guard let storedPassword = userDataDictionary["password"] as? String else {
                            print("Password field missing or not a String for email: \(email)")
                            self.showAlert(title: "Login Failed", message: "User data incomplete. Cannot log in.")
                            return
                        }

                  
                        if password == storedPassword {
                            print("Custom DB Authentication Successful for \(email)")

                            // Check if rewards have already been claimed
                            let rewardsAlreadyClaimed = userDataDictionary["rewardsClaimed"] as? Bool ?? false

                            if !rewardsAlreadyClaimed {
                                // Rewards not claimed yet, update the database and show special alert
                                print("Rewards not claimed for user \(userID). Attempting to update.")
                                self.ref.child("users").child(userID).child("rewardsClaimed").setValue(true) { (error, dbRef) in
                                    DispatchQueue.main.async {
                                        if let error = error {
                                            print("Failed to update rewardsClaimed status: \(error.localizedDescription)")
                                            // Decide how to handle: Log error? Alert user? Proceed anyway?
                                            // For now, show success but log the error.
                                            self.showAlert(title: "Login Successful", message: "Logged in, but failed to update reward status.") {
                                                self.performSegue(withIdentifier: "toHomeScreenFromL", sender: self)
                                            }
                                        } else {
                                            print("Successfully updated rewardsClaimed status for user \(userID).")
                                            self.showAlert(title: "Login Successful", message: "Welcome! Initial rewards claimed.") {
                                                self.performSegue(withIdentifier: "toHomeScreenFromL", sender: self)
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Rewards already claimed, just log in normally
                                print("Rewards already claimed for user \(userID). Proceeding with login.")
                                // Show standard success alert or just perform segue directly
                                 self.showAlert(title: "Login Successful", message: "Welcome back!") {
                                     self.performSegue(withIdentifier: "toHomeScreenFromL", sender: self)
                                 }
                                // Or directly: self.performSegue(withIdentifier: "toHomeScreenFromL", sender: self)
                            }

                        } else {
                            print("Incorrect password provided for email: \(email)")
                            self.showAlert(title: "Login Failed", message: "Invalid email or password.")
                        }
                        // --- End: INSECURE Password Check ---

                    } withCancel: { [weak self] (error) in
                        guard let self = self else { return }
                        print("Database query failed with error: \(error.localizedDescription)")
                        self.showAlert(title: "Database Error", message: "Could not connect to the database. Please try again later. (\(error.localizedDescription))")
                    }
                }

                // Updated showAlert to include an optional completion handler
                func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            completion?() // Execute the completion handler if provided
                        })
                        self.present(alert, animated: true)
                    }
                }

                func setupKeyboardDismissal() {
                     let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
                     tapGesture.cancelsTouchesInView = false
                     view.addGestureRecognizer(tapGesture)
                 }

                 @objc func dismissKeyboard() {
                     view.endEditing(true)
                 }
            }
