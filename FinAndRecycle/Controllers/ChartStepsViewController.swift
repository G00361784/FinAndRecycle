import UIKit
import SwiftUI
import Charts
import HealthKit // Keep for potential future use or other HK features

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
    private let hardcodedSteps: Double = 7500.0

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if isLoading {
                    ProgressView("Loading Chart Data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if stepData.isEmpty {
                     Text("No step data to display.")
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
                            // Optional: Add annotation to show the value
                            .annotation(position: .top) {
                                Text("\(Int(dataPoint.value))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
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
                            AxisValueLabel() // Automatically determines labels
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
                             // Optional: Add annotation
                            .annotation(position: .top) {
                                Text(String(format: "%.2f", carbonSaving))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
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
                // Generate data when the view appears if not already loaded
                if stepData.isEmpty && errorMessage == nil {
                    generateHardcodedStepData() // Call the new generation function
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // --- MODIFIED: Function to generate hardcoded data ---
    func generateHardcodedStepData() {
        isLoading = true
        errorMessage = nil
        print("Generating hardcoded step data...")

        var tempData: [ChartDataPoint] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date()) // Get start of today

        // Generate data points for the last 7 days including today
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                tempData.append(ChartDataPoint(date: date, value: hardcodedSteps))
            }
        }

        
        self.stepData = tempData.sorted { $0.date < $1.date }
        self.isLoading = false // Mark loading as complete
        print("Hardcoded step data generated: \(self.stepData.count) points")
    }


    // --- REMOVED HealthKit Fetching Logic from ContentView ---
    // func fetchStepData() { ... } // Removed
    // func performStepQuery(...) { ... } // Removed
    // --- End Removal ---

    func calculateCarbonSaving(for steps: Double) -> Double {
        return steps * carbonFactor
    }
}

// MARK: - UIKit Host View Controller
class ChartStepsViewController: UIViewController {

    var hostingController: UIHostingController<ContentView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Authorize HealthKit - still useful to check availability or for other features
        authorizeHealthKit { [weak self] success in
            guard let self = self else { return }
            // Always setup the SwiftUI view as it uses hardcoded data
            self.setupSwiftUIView()
            // Optionally show error if auth failed and it's needed for other things
            // if !success {
            //     self.showAuthorizationError()
            // }
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

    // Modified authorizeHealthKit
    func authorizeHealthKit(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available.")
            // Even if HK not available, we can proceed because steps are hardcoded
            completion(true)
            return
        }

        let healthStore = HKHealthStore()

        // --- FIX: Ensure at least one type is requested ---
        // We need to request *something*, even if we don't use it for the chart.
        // Let's request step count type for consistency or future use.
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
             print("Step count type unavailable.")
             // Allow UI setup anyway for hardcoded data
             completion(true)
             return
        }
        let typesToRead: Set<HKSampleType> = [stepCountType]
        // Add other types like HKObjectType.workoutType() if needed for other features
        // -------------------------------------------------

        // Request authorization
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { (success, error) in
             if let error = error {
                 print("HealthKit authorization request error: \(error.localizedDescription)")
                 // Decide if failure should prevent UI setup or just be logged
                 completion(false) // Or true if UI should show regardless
                 return
             }
             if success {
                 print("HealthKit authorization request successful (or status checked).")
                 completion(true)
             } else {
                 print("HealthKit authorization request denied.")
                 completion(false) // Or true if UI should show regardless
             }
         }
    }
}
