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
    override func viewDidLoad() {
        super.viewDidLoad()
        Task
         {
                    await requestAuthorization()
                    await calculateSteps()
                }
        // Do any additional setup after loading the view.
    }

    
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let healthDataTypes = Set([HKQuantityType.quantityType(forIdentifier: .stepCount)!])

        try? await HKHealthStore().requestAuthorization(toShare: [], read: healthDataTypes)
    }
    func calculateSteps() async {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let stepQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let query = HKStatisticsQuery(quantityType: stepQuantityType,
                                    quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                // Handle error or no data
                return
            }
            
            // Assuming sum is not nil, we can get the double value
            let steps = sum.doubleValue(for: HKUnit.count())
            // Do something with the steps value, e.g., update UI
            
            
            
            DispatchQueue.main.async {
                self.stepsTodayLabel.text = "Today you walked \(Int(round(steps))) Steps"
            }
        }
        // Execute the query
        await HKHealthStore().execute(query)
    }
}
