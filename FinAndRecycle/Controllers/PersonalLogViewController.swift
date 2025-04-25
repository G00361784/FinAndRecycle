//
//  PersonalLogViewController.swift
//  EFootPrint
//
//  Created by Joseph Mccole on 03/12/2024.
//

import UIKit
import HealthKit


class WorkoutLogCell: UITableViewCell {
    static let identifier = "WorkoutLogCell"
    @IBOutlet weak var activityLabel: UILabel! // e.g., "Running"
    @IBOutlet weak var dateLabel: UILabel!     // e.g., "Apr 25, 10:30 AM"
    @IBOutlet weak var detailsLabel: UILabel!  // e.g., "30 min - 350 kcal - 5.2 km"

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    func configure(with workout: HKWorkout) {
        activityLabel.text = workout.workoutActivityType.name
        dateLabel.text = dateFormatter.string(from: workout.startDate)

        var detailsParts: [String] = []
        let durationMinutes = workout.duration / 60
        if durationMinutes >= 1 { // Only show duration if 1 minute or more
             detailsParts.append(String(format: "%.0f min", durationMinutes))
        }

        if let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()), energy > 0 {
            detailsParts.append(String(format: "%.0f kcal", energy))
        }
        if let distance = workout.totalDistance?.doubleValue(for: .meter()), distance > 0 {
             // Convert meters to kilometers or miles based on locale if needed
            detailsParts.append(String(format: "%.2f km", distance / 1000))
        }

        detailsLabel.text = detailsParts.joined(separator: " - ")
        detailsLabel.isHidden = detailsParts.isEmpty
    }
}






class PersonalLogViewController: UIViewController,UITableViewDataSource {

    
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepsTodayLabel: UILabel!

    @IBOutlet weak var co2SavingsLabel: UILabel!
    
    @IBOutlet weak var workoutTableView: UITableView!
    
    
    // --- HealthKit ---
       private let healthStore = HKHealthStore()
       private var workouts: [HKWorkout] = [] // To store fetched workouts

       // --- Constants & Formatters ---
       private let carbonFactor: Double = 0.2 / 1000 // kg CO2 saved per step
       private lazy var dateFormatter: DateFormatter = {
           let formatter = DateFormatter()
           formatter.dateStyle = .medium
           formatter.timeStyle = .none
           return formatter
       }()
       private lazy var numberFormatter: NumberFormatter = {
           let formatter = NumberFormatter()
           formatter.numberStyle = .decimal
           formatter.maximumFractionDigits = 0
           return formatter
       }()
       private lazy var co2Formatter: NumberFormatter = {
           let formatter = NumberFormatter()
           formatter.numberStyle = .decimal
           formatter.minimumFractionDigits = 2
           formatter.maximumFractionDigits = 2
           return formatter
       }()

       // --- Lifecycle Methods ---
       override func viewDidLoad() {
           super.viewDidLoad()
           setupInitialUI()

           // Configure the workout table view
           workoutTableView.dataSource = self
           // Optional: Set estimated row height for better performance
           workoutTableView.estimatedRowHeight = 60
           workoutTableView.rowHeight = UITableView.automaticDimension

           // Start the process to get HealthKit data
           Task {
               await requestHealthKitAuthorization()
           }
       }

       // --- UI Setup ---
       private func setupInitialUI() {
           dateLabel.text = dateFormatter.string(from: Date())
           stepsTodayLabel.text = "Loading steps..."
           co2SavingsLabel.text = "CO₂ Saved: -"
           // Add placeholder for workouts
           // You might want a label above the table view saying "Recent Workouts"
           // Initially hide the table or show an empty state message
           workoutTableView.isHidden = true // Hide until data is loaded or show empty state
       }

       // --- HealthKit Logic ---
       private func requestHealthKitAuthorization() async {
           guard HKHealthStore.isHealthDataAvailable() else {
               updateUI(error: "Health data not available.")
               // --- Add Hardcoded Data even if HealthKit unavailable (for testing) ---
               addHardcodedRunningWorkout()
               DispatchQueue.main.async {
                   self.workoutTableView.isHidden = self.workouts.isEmpty
                   self.workoutTableView.reloadData()
               }
               // -----------------------------------------------------------------------
               return
           }

           // --- Define types to read: Steps AND Workouts ---
           // HKObjectType.workoutType() is not optional, so no 'guard let' needed for it.
           guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
               updateUI(error: "HealthKit step type unavailable.")
               print("Error: Unable to get step count type identifier.")
               return
           }
           // Get workout type directly
           let workoutType = HKObjectType.workoutType()

           let healthDataTypes: Set = [stepType, workoutType] // Request both

           var fetchedWorkouts: [HKWorkout]? // Declare here to use in catch block

           do {
               try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)
               // Authorization finished, now fetch data
               print("HealthKit authorization attempt finished.")
               // Fetch both steps and workouts concurrently
               async let stepsResult: Int? = fetchTodaysSteps()
               async let workoutsResult: [HKWorkout]? = fetchRecentWorkoutsAsync()

               // Await results and update UI
               let steps = await stepsResult
               fetchedWorkouts = await workoutsResult // Assign to outer variable

               updateUI(steps: steps) // Update step labels

               if let fetched = fetchedWorkouts {
                   self.workouts = fetched // Replace existing workouts with fetched ones
               } else {
                    print("Failed to fetch workouts or authorization denied.")
                    self.workouts = [] // Clear workouts if fetch failed
               }

           } catch {
               print("Authorization failed: \(error.localizedDescription)")
               updateUI(error: "Authorization failed.")
               self.workouts = [] // Clear workouts on authorization error
           }

           // --- Add Hardcoded Data AFTER attempting fetch ---
           addHardcodedRunningWorkout()
           // ------------------------------------------------

           // --- Update Table View on Main Thread ---
           DispatchQueue.main.async {
                print("Final workout count (including hardcoded): \(self.workouts.count)")
                // Sort combined list (optional, if needed)
                self.workouts.sort { $0.startDate > $1.startDate }
                self.workoutTableView.isHidden = self.workouts.isEmpty
                self.workoutTableView.reloadData()
                // Optionally show an empty state message in the table view background if workouts.isEmpty
           }
           // -----------------------------------------
       }

       // --- Function to add a hardcoded workout ---
       private func addHardcodedRunningWorkout() {
           print("Adding hardcoded running workout...")
           // Create sample dates (e.g., today at 9:00 AM for 30 mins)
           let calendar = Calendar.current
           var components = calendar.dateComponents([.year, .month, .day], from: Date())
           components.hour = 9
           components.minute = 0
           guard let startDate = calendar.date(from: components),
                 let endDate = calendar.date(byAdding: .minute, value: 30, to: startDate) else {
               print("Error creating hardcoded dates.")
               return
           }

           // Create sample quantities (optional)
           let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: 250.0)
           let distance = HKQuantity(unit: .meter(), doubleValue: 3500.0)

           // Create the hardcoded workout
           let hardcodedWorkout = HKWorkout(
               activityType: .running,
               start: startDate,
               end: endDate,
               duration: endDate.timeIntervalSince(startDate), // Calculate duration
               totalEnergyBurned: energyBurned,
               totalDistance: distance,
               metadata: [HKMetadataKeyWorkoutBrandName: "Hardcoded Example"] // Example metadata
           )

           // Append to the workouts array
           // Use prepend to add it to the top, or append to add to the bottom
           self.workouts.append(hardcodedWorkout)
       }
       // -----------------------------------------


       // --- Fetch Steps (Adapted from original calculateSteps) ---
       private func fetchTodaysSteps() async -> Int? {
           guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
           let now = Date()
           let startOfDay = Calendar.current.startOfDay(for: now)
           let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

           // Use continuation for cleaner async/await with HKStatisticsQuery
           let steps: Int? = await withCheckedContinuation { continuation in
               let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                   guard let result = result, let sum = result.sumQuantity() else {
                       if let error = error {
                           print("Error fetching step data: \(error.localizedDescription)")
                           // Check if error is due to authorization
                           if let hkError = error as? HKError, hkError.code == .errorAuthorizationDenied {
                                print("Step count authorization denied.")
                           }
                       } else {
                           print("No step data available for today.")
                       }
                       continuation.resume(returning: nil) // Return nil on error or no data
                       return
                   }
                   let stepCount = Int(sum.doubleValue(for: HKUnit.count()))
                   continuation.resume(returning: stepCount) // Return the step count
               }
               healthStore.execute(query)
           }
           return steps
       }

       // --- Fetch Workouts (Async version) ---
       private func fetchRecentWorkoutsAsync(days: Int = 7) async -> [HKWorkout]? {
           // HKObjectType.workoutType() is not optional, assigned directly
           let workoutType = HKObjectType.workoutType()
           let calendar = Calendar.current
           let endDate = Date()
           guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
               print("Error creating start date for workout query.")
               return nil
           }
           let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
           let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

           // Use continuation to bridge HKSampleQuery completion handler to async/await
           return await withCheckedContinuation { continuation in
               let query = HKSampleQuery(
                   sampleType: workoutType, // Use the directly assigned workoutType
                   predicate: datePredicate,
                   limit: HKObjectQueryNoLimit,
                   sortDescriptors: [sortDescriptor]
               ) { _, samples, error in
                   if let error = error {
                       print("Error fetching workouts: \(error.localizedDescription)")
                        if let hkError = error as? HKError, hkError.code == .errorAuthorizationDenied {
                            print("Workout authorization denied.")
                       }
                       continuation.resume(returning: nil) // Return nil on error
                       return
                   }
                   guard let fetchedWorkouts = samples as? [HKWorkout] else {
                       print("Could not cast samples to HKWorkout.")
                       continuation.resume(returning: nil) // Return nil if casting fails
                       return
                   }
                   continuation.resume(returning: fetchedWorkouts) // Return fetched workouts
               }
               healthStore.execute(query)
           }
       }


       // --- Carbon Calculation ---
       private func calculateCarbonSaving(for steps: Int) -> Double {
           return Double(steps) * carbonFactor
       }

       // --- UI Update Function (Handles Steps/CO2 Labels) ---
       private func updateUI(steps: Int? = nil, error: String? = nil) {
           DispatchQueue.main.async { // Ensure UI updates are on main thread
               if let errorMessage = error {
                   self.stepsTodayLabel.text = errorMessage
                   self.co2SavingsLabel.text = "CO₂ Saved: -"
               } else if let stepCount = steps {
                   let formattedSteps = self.numberFormatter.string(from: NSNumber(value: stepCount)) ?? "\(stepCount)"
                   self.stepsTodayLabel.text = "\(formattedSteps) Steps Today"

                   let co2Saved = self.calculateCarbonSaving(for: stepCount)
                   let formattedCO2 = self.co2Formatter.string(from: NSNumber(value: co2Saved)) ?? "\(co2Saved)"
                   self.co2SavingsLabel.text = "CO₂ Saved: \(formattedCO2) kg"
               } else {
                   // Default state if neither steps nor error is provided
                   self.stepsTodayLabel.text = "Steps unavailable"
                   self.co2SavingsLabel.text = "CO₂ Saved: -"
               }
           }
       }

       // MARK: - UITableViewDataSource Methods for Workouts

       func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
           // Ensure this is only called for the workoutTableView if you have multiple tables
           if tableView == workoutTableView {
               return workouts.count
           }
           return 0 // Return 0 for any other table view
       }

       func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            // Ensure this is only called for the workoutTableView
           guard tableView == workoutTableView else {
               return UITableViewCell() // Return empty cell for other tables
           }

           guard let cell = tableView.dequeueReusableCell(withIdentifier: WorkoutLogCell.identifier, for: indexPath) as? WorkoutLogCell else {
               // Fallback if cell dequeue fails
               return UITableViewCell()
           }

           let workout = workouts[indexPath.row]
           cell.configure(with: workout)

           return cell
       }

       // Optional: Add a title for the workout section header
       func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            if tableView == workoutTableView && !workouts.isEmpty {
               return "Recent Workouts"
            }
            return nil
       }
   }

   // Helper extension to get readable names for HKWorkoutActivityType (Keep this from previous example)
   extension HKWorkoutActivityType {
       var name: String {
           // ... (keep the full switch statement from the previous HealthKit example)
            switch self {
               case .americanFootball: return "American Football"; case .archery: return "Archery"; case .australianFootball: return "Australian Football"; case .badminton: return "Badminton"; case .baseball: return "Baseball"; case .basketball: return "Basketball"; case .bowling: return "Bowling"; case .boxing: return "Boxing"; case .climbing: return "Climbing"; case .cricket: return "Cricket"; case .crossTraining: return "Cross Training"; case .curling: return "Curling"; case .cycling: return "Cycling"; case .dance: return "Dance"; case .danceInspiredTraining: return "Dance Inspired Training"; case .elliptical: return "Elliptical"; case .equestrianSports: return "Equestrian Sports"; case .fencing: return "Fencing"; case .fishing: return "Fishing"; case .functionalStrengthTraining: return "Functional Strength Training"; case .golf: return "Golf"; case .gymnastics: return "Gymnastics"; case .handball: return "Handball"; case .hiking: return "Hiking"; case .hockey: return "Hockey"; case .hunting: return "Hunting"; case .lacrosse: return "Lacrosse"; case .martialArts: return "Martial Arts"; case .mindAndBody: return "Mind and Body"; case .mixedMetabolicCardioTraining: return "Mixed Cardio"; case .paddleSports: return "Paddle Sports"; case .play: return "Play"; case .preparationAndRecovery: return "Preparation and Recovery"; case .racquetball: return "Racquetball"; case .rowing: return "Rowing"; case .rugby: return "Rugby"; case .running: return "Running"; case .sailing: return "Sailing"; case .skatingSports: return "Skating Sports"; case .snowSports: return "Snow Sports"; case .soccer: return "Soccer"; case .softball: return "Softball"; case .squash: return "Squash"; case .stairClimbing: return "Stair Climbing"; case .surfingSports: return "Surfing Sports"; case .swimming: return "Swimming"; case .tableTennis: return "Table Tennis"; case .tennis: return "Tennis"; case .trackAndField: return "Track and Field"; case .traditionalStrengthTraining: return "Traditional Strength Training"; case .volleyball: return "Volleyball"; case .walking: return "Walking"; case .waterFitness: return "Water Fitness"; case .waterPolo: return "Water Polo"; case .waterSports: return "Water Sports"; case .wrestling: return "Wrestling"; case .yoga: return "Yoga"; case .barre: return "Barre"; case .coreTraining: return "Core Training"; case .crossCountrySkiing: return "Cross Country Skiing"; case .downhillSkiing: return "Downhill Skiing"; case .flexibility: return "Flexibility"; case .highIntensityIntervalTraining: return "HIIT"; case .jumpRope: return "Jump Rope"; case .kickboxing: return "Kickboxing"; case .pilates: return "Pilates"; case .snowboarding: return "Snowboarding"; case .stairs: return "Stairs"; case .stepTraining: return "Step Training"; case .wheelchairWalkPace: return "Wheelchair Walk Pace"; case .wheelchairRunPace: return "Wheelchair Run Pace"; case .taiChi: return "Tai Chi"; case .mixedCardio: return "Mixed Cardio"; case .handCycling: return "Hand Cycling"; case .discSports: return "Disc Sports"; case .fitnessGaming: return "Fitness Gaming"; case .cardioDance: return "Cardio Dance"; case .socialDance: return "Social Dance"; case .pickleball: return "Pickleball"; case .cooldown: return "Cooldown"; case .swimBikeRun: return "Swim Bike Run"; default: return "Other"
            }
       }
   }
