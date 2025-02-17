//
//  RegisterViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 16/02/2025.
//

import UIKit
import Firebase
import FirebaseAuth
class RegisterViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    @IBOutlet weak var RegisterEmail: UITextField!
    @IBOutlet weak var RegisterPassword: UITextField!
    
    
    @IBAction func RegisterPressed(_ sender: UIButton) {
        if let email = RegisterEmail.text, let password = RegisterPassword.text {
            
            // Ensure email and password are not empty
            if email.isEmpty || password.isEmpty {
                // Display an error message to the user (e.g., using an alert)
                showError("Please enter both email and password.")
                return
            }
            
            if password.count < 6 {
                // Display an error for weak password
                showError("Password must be at least 6 characters long.")
                return
            }
            
            // Create user with Firebase Auth
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let e = error {
                    // Display error to the user
                    self.showError(e.localizedDescription)
                } else {
                    // Success! Perform the segue
                   self.performSegue(withIdentifier: "toHomeScreenFromR", sender: self)
                }
            }
        } else {
            // Handle the case where email or password are nil (shouldn't happen)
            showError("Email or password cannot be nil.")
        }
        
        
    }
    func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true, completion: nil)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
