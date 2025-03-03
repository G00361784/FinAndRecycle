//
//  ChartStepsViewController.swift
//  FinAndRecycle
//
//  Created by Joseph Mccole on 03/03/2025.
//

import UIKit
import SwiftUI
import Charts
import HealthKit
class ChartStepsViewController: UIViewController {

    override func viewDidLoad() {
            super.viewDidLoad()

            // Request authorization for HealthKit data
            authorizeHealthKit()

            let contentView = ContentView()
            let hostingController = UIHostingController(rootView: contentView)

            // Add the SwiftUI view to your view hierarchy
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.didMove(toParent: self)

            // Set constraints for the SwiftUI view
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        // Request authorization to read step count from HealthKit
        func authorizeHealthKit() {
            let healthStore = HKHealthStore()
            let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

            healthStore.requestAuthorization(toShare: [], read: [stepCountType]) { (success, error) in
                if !success {
                    // Handle authorization error
                    print("HealthKit authorization failed:", error?.localizedDescription ?? "Unknown error")
                }
            }
        }

    struct ContentView: View {
            @State private var stepData: [(String, Double)] = []

            var body: some View {
                VStack {
                    // First chart (steps)
                    Chart {
                        ForEach(stepData, id: \.0) { dateString, steps in
                            BarMark(
                                x: .value("Date", dateString),
                                y: .value("Steps", steps)
                            )
                            .foregroundStyle(by: .value("Date", dateString))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom) {
                            AxisGridLine()
                            AxisValueLabel(centered: true, anchor: .top) {
                                Text("")
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 200)
                    .padding()

                    // Second chart (carbon savings)
                    Chart {
                        ForEach(stepData, id: \.0) { dateString, steps in
                            let carbonSaving = calculateCarbonSaving(for: steps)

                            BarMark(
                                x: .value("Date", dateString),
                                y: .value("CO2 Savings (kg)", carbonSaving)
                            )
                            .foregroundStyle(by: .value("Date", dateString))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom) {
                            AxisGridLine()
                            AxisValueLabel(centered: true, anchor: .top) {
                                Text("")
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 200)
                    .padding()
                }
                .onAppear {
                    fetchStepData()
                }
            }

        
        func fetchStepData() {
            let healthStore = HKHealthStore()
            let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            
            // Create a predicate to get data from the last 7 days
            let now = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            
            // Create the query
            let query = HKStatisticsCollectionQuery(quantityType: stepCountType,
                                                    quantitySamplePredicate: predicate,
                                                    options: .cumulativeSum,
                                                    anchorDate: startDate,
                                                    intervalComponents: DateComponents(day: 1))
            
            query.initialResultsHandler = { query, results, error in
                guard let results = results else {
                    print("HealthKit query failed:", error?.localizedDescription ?? "Unknown error")
                    return
                }
                
                var tempData: [(String, Double)] = []
                results.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                    if let quantity = statistics.sumQuantity() {
                        // Format the date as "Month Day" (e.g., "Dec 08")
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "MMM dd"
                        let dateString = dateFormatter.string(from: statistics.startDate)
                        
                        let steps = quantity.doubleValue(for: HKUnit.count())
                        tempData.append((dateString, steps))
                    }
                }
                // Update the state with the fetched data
                DispatchQueue.main.async {
                    stepData = tempData
                }
            }
            
            // Execute the query
            healthStore.execute(query)
        }
        func calculateCarbonSaving(for steps: Double) -> Double {
                    // Example: Assume 1000 steps save 0.2 kg CO2
                    return steps * 0.2 / 1000
                }
        
        }

}
