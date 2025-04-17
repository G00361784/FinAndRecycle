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

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ContentView: View {
    @State private var stepData: [ChartDataPoint] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    private let carbonFactor: Double = 0.2 / 1000

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if isLoading {
                    ProgressView("Loading Health Data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if stepData.isEmpty {
                     Text("No step data found for the last 7 days.")
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Daily Steps (Last 7 Days)")
                        .font(.title2)
                        .padding(.leading)

                    Chart {
                        ForEach(stepData) { dataPoint in
                            BarMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("Steps", dataPoint.value)
                            )
                            .foregroundStyle(Color.blue.gradient)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 250)
                    .padding(.horizontal)
                    .padding(.bottom)


                    Text("Estimated CO₂ Savings (kg)")
                        .font(.title2)
                        .padding(.leading)

                    Chart {
                        ForEach(stepData) { dataPoint in
                            let carbonSaving = calculateCarbonSaving(for: dataPoint.value)
                            BarMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("CO₂ Saved", carbonSaving)
                            )
                            .foregroundStyle(Color.green.gradient)
                        }
                    }
                    .chartXAxis {
                         AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 250)
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Activity & Savings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if stepData.isEmpty && errorMessage == nil {
                    fetchStepData()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    func fetchStepData() {
        isLoading = true
        errorMessage = nil
        let healthStore = HKHealthStore()
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            errorMessage = "Step Count Type is unavailable on this device."
            isLoading = false
            return
        }

        healthStore.getRequestStatusForAuthorization(toShare: [], read: [stepCountType]) { (status, error) in
            DispatchQueue.main.async {
                if let error = error {
                     self.errorMessage = "Could not check HealthKit authorization status."
                     self.isLoading = false
                     return
                }

                guard status == .unnecessary else {
                    self.errorMessage = "Please grant HealthKit access in Settings > Health > Data Access & Devices."
                    self.isLoading = false
                    return
                }
                performStepQuery(healthStore: healthStore, stepCountType: stepCountType)
            }
        }
    }


    func performStepQuery(healthStore: HKHealthStore, stepCountType: HKQuantityType) {
        let calendar = Calendar.current
        let now = Date()
        guard let anchorDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now),
              let startDate = calendar.date(byAdding: .day, value: -7, to: anchorDate) else {
            errorMessage = "Could not calculate date range for query."
            isLoading = false
            return
        }
        let endDate = calendar.date(byAdding: .day, value: 1, to: anchorDate) ?? now

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )

        query.initialResultsHandler = { query, results, error in
            DispatchQueue.main.async {
                guard let results = results else {
                    self.errorMessage = "Failed to fetch step data. \(error?.localizedDescription ?? "")"
                    self.isLoading = false
                    return
                }

                var tempData: [ChartDataPoint] = []
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, stop in
                    let steps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    tempData.append(ChartDataPoint(date: statistics.startDate, value: steps))
                }

                 let finalData = Array(tempData.suffix(7))

                self.stepData = finalData
                self.isLoading = false
            }
        }
        healthStore.execute(query)
    }

    func calculateCarbonSaving(for steps: Double) -> Double {
        return steps * carbonFactor
    }
}

class ChartStepsViewController: UIViewController {

    var hostingController: UIHostingController<ContentView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        authorizeHealthKit { [weak self] success in
            guard let self = self else { return }
            if success {
                self.setupSwiftUIView()
            } else {
                self.showAuthorizationError()
            }
        }
    }

    func setupSwiftUIView() {
        DispatchQueue.main.async {
            let contentView = ContentView()
            self.hostingController = UIHostingController(rootView: contentView)

            guard let hcView = self.hostingController?.view else { return }

            self.addChild(self.hostingController!)
            self.view.addSubview(hcView)
            self.hostingController!.didMove(toParent: self)

            hcView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hcView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                hcView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hcView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                hcView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
            ])
        }
    }

    func showAuthorizationError() {
         DispatchQueue.main.async {
            let errorLabel = UILabel()
            errorLabel.text = "HealthKit Authorization Failed. Please enable access in Settings."
            errorLabel.textAlignment = .center
            errorLabel.numberOfLines = 0
            errorLabel.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(errorLabel)

            NSLayoutConstraint.activate([
                errorLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                errorLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
                errorLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
                errorLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20)
            ])
         }
    }

    func authorizeHealthKit(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        let healthStore = HKHealthStore()
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
             completion(false)
             return
        }

        healthStore.getRequestStatusForAuthorization(toShare: [], read: [stepCountType]) { (status, error) in
            if let error = error {
                completion(false)
                return
            }

            if status == .unnecessary {
                 completion(true)
            } else {
                healthStore.requestAuthorization(toShare: [], read: [stepCountType]) { (success, error) in
                    completion(success)
                }
            }
        }
    }
}
