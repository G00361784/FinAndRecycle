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
            guard let currentUser = Auth.auth().currentUser else {
                showLoginWarning()
                return
            }

            let userID = currentUser.uid
            let userRef = ref.child("users").child(userID)

            let updateData = ["rewardsClaimed": true]

            userRef.updateChildValues(updateData) { (error, dbRef) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error updating rewards status: \(error.localizedDescription)")
                        let errorAlert = UIAlertController(title: "Error", message: "Could not claim rewards. Please try again. (\(error.localizedDescription))", preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorAlert, animated: true)
                    } else {
                        print("Successfully updated rewardsClaimed status for user \(userID)")
                        let claimAlert = UIAlertController(title: "Rewards", message: "Rewards claimed!", preferredStyle: .alert)
                        claimAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(claimAlert, animated: true)
                    }
                }
            }
        }
           var ref: DatabaseReference!
           var leaderboardUsers: [[String: Any]] = []

           override func viewDidLoad() {
               super.viewDidLoad()
               tableView.register(UITableViewCell.self, forCellReuseIdentifier: "userCell")
               tableView.dataSource = self
               ref = Database.database().reference()

               if Auth.auth().currentUser == nil {
                   print("User not logged in. Some features might be disabled.")
               }
               fetchLeaderboardData()
           }

           @IBAction func checkUserLogin(_ sender: UIButton) {
               if Auth.auth().currentUser == nil {
                   showLoginWarning()
               } else {
                    let loggedInAlert = UIAlertController(title: "Logged In", message: "You are logged in.", preferredStyle: .alert)
                    loggedInAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(loggedInAlert, animated: true)
               }
           }

           func showLoginWarning() {
               let alert = UIAlertController(title: "Login Required",
                                             message: "You need to be logged in to claim rewards.",
                                             preferredStyle: .alert)
               alert.addAction(UIAlertAction(title: "OK", style: .cancel))
               alert.addAction(UIAlertAction(title: "Login", style: .default, handler: { _ in
                   self.redirectToLogin()
               }))
               present(alert, animated: true, completion: nil)
           }

           func redirectToLogin() {
               let storyboard = UIStoryboard(name: "Main", bundle: nil)
               if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                   loginVC.modalPresentationStyle = .fullScreen
                   present(loginVC, animated: true, completion: nil)
               } else {
                    print("Error: Could not instantiate LoginViewController from Storyboard.")
               }
           }

           func fetchLeaderboardData() {
               ref.child("users").observeSingleEvent(of: .value, with: { (snapshot) in
                   guard let usersData = snapshot.value as? [String: [String: Any]] else {
                        print("Could not fetch or parse users data.")
                        self.leaderboardUsers = []
                        self.tableView.reloadData()
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
                    self.leaderboardUsers = []
                    DispatchQueue.main.async {
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
       }
