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

        // --- No longer needed if triggering segue manually ---
        // var authenticationSuccessful = false

        override func viewDidLoad() {
            super.viewDidLoad()
            // Initialize Database reference
            ref = Database.database().reference()
        }


 





       
        @IBAction func loginPressed(_ sender: UIButton) {
            guard let email = LoginEmail.text, !email.isEmpty,
                  let password = LoginPassword.text, !password.isEmpty else {
                showAlert(title: "Input Missing", message: "Please enter both email and password.")
                return
            }

            // --- Start: Custom DB Authentication (INSECURE) ---
            ref.child("users").queryOrdered(byChild: "email").queryEqual(toValue: email).observeSingleEvent(of: .value) { [weak self] (snapshot) in
                guard let self = self else { return }
                guard snapshot.exists(), let usersData = snapshot.value as? [String: [String: Any]], usersData.count == 1 else {
                    print("No user found for email: \(email)")
                    self.showAlert(title: "Login Failed", message: "Invalid email or password.")
                    return
                }
                if let userData = usersData.first?.value {
                    // ** INSECURE: Assuming a 'password' field exists in your DB **
                    if let storedPassword = userData["password"] as? String {
                        // ** INSECURE: Direct password comparison **
                        if password == storedPassword {
                            print("Custom DB Authentication Successful for \(email)")
                            // You would need custom logic here to store the logged-in state
                            // e.g., let loggedInUserID = usersData.first?.key
                            //      UserDefaults.standard.set(loggedInUserID, forKey: "loggedInUserID")
                            self.performSegue(withIdentifier: "toHomeScreenFromL", sender: self)
                        } else {
                            print("Incorrect password for email: \(email)")
                            self.showAlert(title: "Login Failed", message: "Invalid email or password.")
                        }
                    } else {
                        print("Password field missing or invalid for email: \(email)")
                        self.showAlert(title: "Login Failed", message: "User data incomplete. Cannot log in.")
                    }
                } else {
                     print("Error retrieving user data for email: \(email)")
                     self.showAlert(title: "Login Failed", message: "An error occurred.")
                }
            } withCancel: { [weak self] (error) in
                guard let self = self else { return }
                print("Database query failed: \(error.localizedDescription)")
                self.showAlert(title: "Error", message: "Database error: \(error.localizedDescription)")
            }
            // --- End: Custom DB Authentication (INSECURE) ---
        }

        func showAlert(title: String, message: String) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
