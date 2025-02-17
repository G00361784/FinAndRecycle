//
//  LoginViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 10/02/2025.
//
import UIKit
import FirebaseCore
import FirebaseAuth
class LoginViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBOutlet weak var LoginEmail: UITextField!
    
    @IBOutlet weak var LoginPassword: UITextField!
    
    var authenticationSuccessful = false // This flag is crucial

    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "toHomeScreenFromL" { // Check the segue identifier
            return authenticationSuccessful // A boolean flag you set in your authentication callback
        }
        return true // Allow other segues to perform
    }
    
    @IBAction func loginPressed(_ sender: UIButton) {
        guard let email = LoginEmail.text, !email.isEmpty,
                     let password = LoginPassword.text, !password.isEmpty else {
                   showAlert(message: "Please enter both email and password.") 
                   return
               }
        
        
       // if let email = LoginEmail.text, let password = LoginPassword.text {
            
            
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
                guard let self = self else { return }
                if let e = error {
                            print(e.localizedDescription)
                            self.authenticationSuccessful = false // Set to false on error
                            // Show the error message to the user.
                        } else {
                            self.authenticationSuccessful = true  // Set to true on success
                            // No need to call performSegue here.
                        }
            }
            
        
        
        func showAlert(message: String) {
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
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
