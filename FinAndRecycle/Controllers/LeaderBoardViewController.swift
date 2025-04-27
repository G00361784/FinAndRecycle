//
//  LeaderBoardViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 02/03/2025.
//
import UIKit
import FirebaseCore
import FirebaseDatabase
import FirebaseAuth

class LeaderBoardViewController: UIViewController, UITableViewDataSource  {


    
    @IBOutlet weak var tableView: UITableView!
    
            var ref: DatabaseReference!
            var leaderboardUsers: [[String: Any]] = []

            override func viewDidLoad() {
                super.viewDidLoad()
                tableView.register(UITableViewCell.self, forCellReuseIdentifier: "userCell")
                tableView.dataSource = self
                ref = Database.database().reference()

                // Removed the FirebaseAuth check from here
                fetchLeaderboardData()

                // Optional: Add a Login button programmatically if not using Storyboard
                // setupLoginButton() // Example function call
            }

            // --- NEW: Action for a dedicated Login Button ---
            // You need to add a UIButton in your Storyboard for this View Controller
            // and connect its "Touch Up Inside" event to this IBAction.
            @IBAction func loginButtonTapped(_ sender: UIButton) {
                print("Login button tapped, redirecting...")
                redirectToLogin()
            }
            // -----------------------------------------------


            // Kept: This function redirects to the Login screen using Storyboard ID
            func redirectToLogin() {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                // Ensure "LoginViewController" is the correct Storyboard ID for your Login VC in Main.storyboard
                if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                    loginVC.modalPresentationStyle = .fullScreen // Or your preferred style
                    present(loginVC, animated: true, completion: nil)
                } else {
                    // Log an error if the Login VC cannot be found
                    print("Error: Could not instantiate LoginViewController from Storyboard. Check Storyboard ID.")
                    // Optionally show an alert to the user here
                    let alert = UIAlertController(title: "Error", message: "Could not navigate to login screen.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }

            // Removed: showLoginWarning - No longer needed as redirect is manual

            // --- Data Fetching and Display Logic (Remains the same) ---

            func fetchLeaderboardData() {
                ref.child("users").observeSingleEvent(of: .value, with: { (snapshot) in
                    guard let usersData = snapshot.value as? [String: [String: Any]] else {
                        print("Could not fetch or parse users data.")
                        DispatchQueue.main.async {
                            self.leaderboardUsers = []
                            self.tableView.reloadData()
                        }
                        return
                    }

                    let usersWithScores = usersData.values.filter { userData in
                        if let score = userData["score"] {
                            return score is Int || score is Double || score is String
                        }
                        return false
                    }

                    self.leaderboardUsers = usersWithScores.sorted { (user1Data, user2Data) -> Bool in
                        let score1 = self.extractScore(from: user1Data["score"])
                        let score2 = self.extractScore(from: user2Data["score"])
                        return score1 > score2
                    }

                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }) { (error) in
                    print("Firebase Database error: \(error.localizedDescription)")
                     DispatchQueue.main.async {
                        self.leaderboardUsers = []
                        self.tableView.reloadData()
                    }
                }
            }

            private func extractScore(from value: Any?) -> Int {
                if let intScore = value as? Int {
                    return intScore
                } else if let doubleScore = value as? Double {
                    return Int(doubleScore)
                } else if let stringScore = value as? String, let intScore = Int(stringScore) {
                    return intScore
                }
                return 0
            }

            // MARK: - UITableViewDataSource Methods (Unchanged)

            func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
                return leaderboardUsers.count
            }

            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath)
                let userData = leaderboardUsers[indexPath.row]

                let email = userData["email"] as? String ?? "No Email"
                let score = extractScore(from: userData["score"])

                cell.textLabel?.text = "\(indexPath.row + 1). \(email) - Score: \(score)"
                cell.textLabel?.numberOfLines = 0

                return cell
            }

            // --- Example: How to add a login button programmatically (if needed) ---
            /*
            func setupLoginButton() {
                let loginButton = UIButton(type: .system)
                loginButton.setTitle("Go to Login", for: .normal)
                loginButton.translatesAutoresizingMaskIntoConstraints = false
                loginButton.addTarget(self, action: #selector(loginButtonTappedAction), for: .touchUpInside) // Use different selector if IBAction exists
                view.addSubview(loginButton)

                // Add constraints for the button (e.g., pin to bottom or top corner)
                NSLayoutConstraint.activate([
                    loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    loginButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20) // Example position
                ])
            }

            @objc func loginButtonTappedAction() { // Need separate @objc func if adding programmatically AND using IBAction
                 redirectToLogin()
            }
            */
        }
