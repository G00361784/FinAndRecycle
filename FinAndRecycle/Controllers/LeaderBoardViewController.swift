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
        var players: [[String: Any]] = []

        override func viewDidLoad() {
            super.viewDidLoad()
            
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "playerCell")
            tableView.dataSource = self
            ref = Database.database().reference()
            
            checkUserAuthentication()
        }
        
        func checkUserAuthentication() {
            if Auth.auth().currentUser == nil {
                // Redirect to login if no user is authenticated
                redirectToLogin()
            } else {
                fetchLeaderboardData()
            }
        }
        
        func redirectToLogin() {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                loginVC.modalPresentationStyle = .fullScreen
                present(loginVC, animated: true, completion: nil)
            }
        }
        
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


