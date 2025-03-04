//
//  PersonalLogViewController.swift
//  EFootPrint
//
//  Created by Joseph Mccole on 03/12/2024.
//

import UIKit
import HealthKit

class PersonalLogViewController: UIViewController {

    
    
    @IBOutlet weak var stepsTodayLabel: UILabel!

        
        private let healthStore = HKHealthStore() // Reusing health store instance

        override func viewDidLoad() {
            super.viewDidLoad()
            Task {
                await requestAuthorization()
                await calculateSteps()
            }
        }

        private func requestAuthorization() async {
            guard HKHealthStore.isHealthDataAvailable() else {
                updateStepsLabel(with: "Health data not available.")
                return
            }

            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let healthDataTypes: Set = [stepType]

            do {
                try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)
            } catch {
                print("Authorization failed: \(error.localizedDescription)")
                updateStepsLabel(with: "Authorization failed.")
            }
        }

        private func calculateSteps() async {
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                
                guard let result = result, let sum = result.sumQuantity() else {
                    if let error = error {
                        print("Error fetching step data: \(error.localizedDescription)")
                    } else {
                        print("No step data available.")
                    }
                    self.updateStepsLabel(with: "Steps data unavailable.")
                    return
                }

                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                self.updateStepsLabel(with: "Today you walked \(steps) Steps")
            }

            healthStore.execute(query)
        }
        
        private func updateStepsLabel(with text: String) {
            DispatchQueue.main.async {
                self.stepsTodayLabel.text = text
            }
        }
    }
