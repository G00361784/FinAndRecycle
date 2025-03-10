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
    
    @IBAction func ClaimRewardsAction(_ sender: Any) {
        if Auth.auth().currentUser == nil {
            showLoginWarning()
        } else {
            // Handle reward claim logic
            print("Reward claimed successfully!")
        }}
    
        var ref: DatabaseReference!
        var players: [[String: Any]] = []
        
        override func viewDidLoad() {
            super.viewDidLoad()
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "playerCell")
            tableView.dataSource = self
            ref = Database.database().reference()
            if Auth.auth().currentUser == nil {
                    showLoginWarning()
                }
            fetchLeaderboardData() // Always load leaderboard
        }

        // Button action to check user login (optional for rewards)
        @IBAction func checkUserLogin(_ sender: UIButton) {
            if Auth.auth().currentUser == nil {
                showLoginWarning() // Shows a warning but does NOT block leaderboard
            }
        }

        // Show an alert if the user is not logged in (only a warning)
        func showLoginWarning() {
            let alert = UIAlertController(title: "Limited Access",
                                          message: "You can view the leaderboard, but some features may be restricted until you log in.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            alert.addAction(UIAlertAction(title: "Login", style: .default, handler: { _ in
                self.redirectToLogin()
            }))
            present(alert, animated: true, completion: nil)
        }

        // Redirect user to login screen
        func redirectToLogin() {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                loginVC.modalPresentationStyle = .fullScreen
                present(loginVC, animated: true, completion: nil)
            }
        }

        // Fetch leaderboard data for everyone
        func fetchLeaderboardData() {
            ref.child("playerinfo").observeSingleEvent(of: .value, with: { (snapshot) in
                guard let value = snapshot.value as? [String: [String: Any]] else { return }

                self.players = value.values.sorted { (player1, player2) -> Bool in
                    let score1 = player1["score"] as? Int ?? 0
                    let score2 = player2["score"] as? Int ?? 0
                    return score1 > score2
                }

                self.tableView.reloadData()
            }) { (error) in
                print(error.localizedDescription)
            }
        }

        // MARK: - UITableViewDataSource

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return players.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "playerCell", for: indexPath)
            let player = players[indexPath.row]

            let name = player["name"] as? String ?? "Unknown"
            let age = player["age"] as? Int ?? 0
            let score = player["score"] as? Int ?? 0

            cell.textLabel?.text = "\(name) - Age: \(age) - Score: \(score)"

            return cell
        }

    }
