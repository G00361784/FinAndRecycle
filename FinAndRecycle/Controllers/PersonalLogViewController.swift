//
//  PersonalLogViewController.swift
//  EFootPrint
//
//  Created by Joseph Mccole on 03/12/2024.
//

import UIKit
import HealthKit

class PersonalLogViewController: UIViewController {

    
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepsTodayLabel: UILabel!

    @IBOutlet weak var co2SavingsLabel: UILabel!
    
    private let healthStore = HKHealthStore()
        private let carbonFactor: Double = 0.2 / 1000 // kg CO2 saved per step (adjust as needed)
        private lazy var dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium // e.g., "Apr 17, 2025"
            formatter.timeStyle = .none
            return formatter
        }()
        private lazy var numberFormatter: NumberFormatter = {
               let formatter = NumberFormatter()
               formatter.numberStyle = .decimal // For steps formatting
               formatter.maximumFractionDigits = 0
               return formatter
           }()
        private lazy var co2Formatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2 // For CO2 formatting (e.g., 0.45 kg)
            return formatter
        }()


        // --- Lifecycle Methods ---
        override func viewDidLoad() {
            super.viewDidLoad()
            setupInitialUI() // Set up date, icons, and initial text

            // Start the process to get HealthKit data
            Task {
                await requestAuthorizationAndFetchSteps()
            }
        }

        // --- UI Setup ---
        private func setupInitialUI() {
            // Set current date
            dateLabel.text = dateFormatter.string(from: Date())

            // Set initial placeholder text
            stepsTodayLabel.text = "Loading steps..."
            co2SavingsLabel.text = "CO₂ Saved: -"

            // Configure icons (if outlets are connected or doing it programmatically)
            // stepsIconImageView?.image = UIImage(systemName: "figure.walk")
            // co2IconImageView?.image = UIImage(systemName: "leaf.fill")
            // stepsIconImageView?.tintColor = .systemOrange // Example color
            // co2IconImageView?.tintColor = .systemGreen  // Example color
        }

        // --- HealthKit Logic ---
        private func requestAuthorizationAndFetchSteps() async {
            guard HKHealthStore.isHealthDataAvailable() else {
                updateUI(error: "Health data not available.")
                return
            }

            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let healthDataTypes: Set = [stepType]

            do {
                try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)
                // Authorization finished (successfully or not), now try fetching steps
                await calculateSteps()
            } catch {
                print("Authorization failed: \(error.localizedDescription)")
                updateUI(error: "Authorization failed.")
            }
        }

        private func calculateSteps() async {
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            // Use continuation for cleaner async/await with HKStatisticsQuery
            let steps: Int? = await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                    guard let result = result, let sum = result.sumQuantity() else {
                        if let error = error {
                            print("Error fetching step data: \(error.localizedDescription)")
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

            // Update UI based on the result from the continuation
            if let stepCount = steps {
                 updateUI(steps: stepCount)
            } else {
                 updateUI(error: "Steps data unavailable.")
            }
        }

        // --- Carbon Calculation ---
        private func calculateCarbonSaving(for steps: Int) -> Double {
            return Double(steps) * carbonFactor
        }

        // --- UI Update Function ---
        private func updateUI(steps: Int? = nil, error: String? = nil) {
            DispatchQueue.main.async {
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
                     // Default state if neither steps nor error is provided (shouldn't normally happen)
                    self.stepsTodayLabel.text = "Steps unavailable"
                    self.co2SavingsLabel.text = "CO₂ Saved: -"
                }
            }
        }
    }
