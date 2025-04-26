import UIKit
import Foundation
import CoreMotion
class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var stepCountLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!

        // Stores fetched news articles
        var articles: [Article] = []
        
    let pedometer = CMPedometer()

    
        // API key for accessing the News API - Remember to keep API keys secure in real apps!
        private let apiKey = "f869c8bcd91543ac9b9689504470c0be"
        // Struct representing the JSON response from the News API
        struct NewsResponse: Codable {
            let articles: [Article] // Array of articles
        }
        
        // Struct representing an individual news article
        struct Article: Codable {
            let title: String?       // Title of the article
            let description: String? // Short description of the article
            let urlToImage: String?  // URL for the article's image
            let url: String?         // URL for the full article (Added for potential use in DetailViewController)
        }
        
        // MARK: - ViewController Lifecycle
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            title = "News Feed"
            
            stepCountLabel.text = "Checking..." // Initial text
            requestAuthorizationAndQuerySteps()
            
            
            // Ensure collectionView is connected in Storyboard or create programmatically
            if collectionView == nil {
                // If not using Storyboard, you'd create and add the collection view here
                print("Error: CollectionView is not connected.")
                // Example programmatic setup (if needed):
                // let layout = UICollectionViewFlowLayout()
                // collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
                // collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                // view.addSubview(collectionView)
                // setupCollectionView() // Call setup after creating it
                // fetchNews()
                return // Stop if collection view isn't set up
            }
            
            // Setup the collection view layout and register cells
            setupCollectionView()
            
            // Fetch news articles from the API
            fetchNews()
        }
        
        // MARK: - CollectionView Setup
        
        func setupCollectionView() {
            let layout = UICollectionViewFlowLayout()
            let horizontalPadding: CGFloat = 15 // Consistent padding
            let interItemSpacing: CGFloat = 10
            let lineSpacing: CGFloat = 15

            layout.minimumInteritemSpacing = interItemSpacing
            layout.minimumLineSpacing = lineSpacing
            // Add vertical padding as well
            layout.sectionInset = UIEdgeInsets(top: lineSpacing, left: horizontalPadding, bottom: lineSpacing, right: horizontalPadding)

            // Calculate cell width based on screen width and padding
            let availableWidth = view.frame.width - (horizontalPadding * 2) // Total width minus left/right padding
            // let cellWidth = availableWidth // Full width cell
            let cellWidth = availableWidth // Or adjust if you want multiple columns: (availableWidth - interItemSpacing) / 2

            // Estimate height - actual height might vary based on content. Using a fixed ratio here.
            // A self-sizing cell approach might be better for dynamic content.
            let cellHeight = cellWidth * 0.8 + 60 // Approximate aspect ratio + text space estimate
            layout.itemSize = CGSize(width: cellWidth, height: cellHeight)

            collectionView.collectionViewLayout = layout
            collectionView.backgroundColor = .clear // Make collection view background clear
            collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.alwaysBounceVertical = true // Allow scrolling even if content fits
        }
        
        // MARK: - Fetching News from API
        
        func fetchNews() {
            let query = "Ocean Environment" // Search query for news
            // URL encode the query term
            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                print("Error: Could not encode query term.")
                return
            }
            let urlString = "https://newsapi.org/v2/everything?q=\(encodedQuery)&language=en&sortBy=publishedAt&apiKey=\(apiKey)"
            
            // Convert the string into a URL
            guard let url = URL(string: urlString) else {
                print("Error: Invalid URL string: \(urlString)")
                return
            }
            
            // Create a data task to fetch the news
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                // Ensure self is available
                guard let self = self else { return }
                
                // Handle network errors
                if let error = error {
                    print("Error fetching news: \(error.localizedDescription)")
                    // Optionally show an error message to the user on the main thread
                    DispatchQueue.main.async {
                        // self.showError("Could not load news. Please check your connection.")
                    }
                    return
                }
                
                // Check HTTP response status
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    print("Error: Invalid HTTP response code: \(statusCode)")
                     DispatchQueue.main.async {
                        // self.showError("Failed to fetch news (Code: \(statusCode)).")
                     }
                    return
                }
                
                // Ensure data was received
                guard let data = data else {
                    print("No data received")
                     DispatchQueue.main.async {
                        // self.showError("No data received from server.")
                     }
                    return
                }
                
                // Decode the JSON response
                do {
                    let decoder = JSONDecoder()
                    let newsResponse = try decoder.decode(NewsResponse.self, from: data)
                    
                    // Update UI on the main thread
                    DispatchQueue.main.async {
                        self.articles = newsResponse.articles
                        // Filter out articles potentially without title or image if needed
                        // self.articles = newsResponse.articles.filter { $0.title != nil && $0.urlToImage != nil }
                        self.collectionView.reloadData() // Reload collection view to display articles
                        print("Successfully fetched \(self.articles.count) articles.")
                    }
                } catch {
                    print("Decoding error: \(error)")
                    print("Decoding error details: \(error.localizedDescription)")
                    // Optionally try to print the data string to see what was received
                     if let dataString = String(data: data, encoding: .utf8) {
                         print("Received data string: \(dataString)")
                     }
                    DispatchQueue.main.async {
                        // self.showError("Error processing news data.")
                    }
                }
            }
            task.resume() // Start the network request
        }
        
        // MARK: - UICollectionViewDataSource
        
        // Returns the number of articles to be displayed
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return articles.count
        }
        
        // Creates and configures a cell for each article
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            // Dequeue the custom cell
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeedCell", for: indexPath) as? FeedCell else {
                // Fallback to a default cell if casting fails (should not happen if registered correctly)
                return UICollectionViewCell()
            }
            let article = articles[indexPath.item] // Use .item for index path in collection views
            cell.configure(with: article) // Configure the cell with article data
            return cell
        }
        
        // MARK: - UICollectionViewDelegate
        
        // Handles user tapping on a news item
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let selectedArticle = articles[indexPath.item]
            let detailVC = DetailViewController() // Instantiate the DetailViewController
            detailVC.article = selectedArticle
            
            // Navigate to the details screen
            navigationController?.pushViewController(detailVC, animated: true)
        }
        
        // MARK: - FeedCell (Custom Collection View Cell with Rounded Corners)
        class FeedCell: UICollectionViewCell {
            let newsImageView = UIImageView()
            let titleLabel = UILabel()
            let descriptionLabel = UILabel()

            override init(frame: CGRect) {
                super.init(frame: frame)
                setupViews()
            }

            required init?(coder aDecoder: NSCoder) {
                super.init(coder: aDecoder)
                // If initialized from Storyboard/XIB, ensure setupViews is called.
                // May already be called depending on lifecycle, but doesn't hurt to ensure.
                setupViews()
            }

            func setupViews() {
                // --- Shadow Configuration (Applied to the cell's main layer) ---
                layer.shadowColor = UIColor.black.cgColor
                layer.shadowOpacity = 0.1
                layer.shadowOffset = CGSize(width: 0, height: 3)
                layer.shadowRadius = 5
                layer.masksToBounds = false // IMPORTANT: Don't clip the shadow
                // Optional: Improve shadow performance by providing a path
                // Note: This needs to be updated if the cell bounds change significantly after initial layout
                layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 10).cgPath
                layer.shouldRasterize = true
                layer.rasterizationScale = UIScreen.main.scale

                // --- ContentView Configuration (Background, Rounded Corners, Clipping) ---
                contentView.backgroundColor = .white
                contentView.layer.cornerRadius = 10 // <<< Apply rounded corners here
                contentView.layer.masksToBounds = true // <<< Clip content to rounded corners

                // --- Subview Setup ---
                newsImageView.contentMode = .scaleAspectFill
                newsImageView.clipsToBounds = true // Keep this to ensure image itself is clipped if needed
                // newsImageView.layer.cornerRadius = 10 // Not strictly needed if contentView clips, but can ensure top corners are rounded if image reaches the very top edge before padding

                titleLabel.font = UIFont.boldSystemFont(ofSize: 17) // Slightly adjusted size
                titleLabel.numberOfLines = 2 // Allow up to two lines for title

                descriptionLabel.font = UIFont.systemFont(ofSize: 14) // Slightly adjusted size
                descriptionLabel.numberOfLines = 3 // Allow up to three lines for description
                descriptionLabel.textColor = .darkGray

                // --- StackView Setup ---
                let textStackView = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
                textStackView.axis = .vertical
                textStackView.spacing = 4 // Spacing between title and description

                let mainStackView = UIStackView(arrangedSubviews: [newsImageView, textStackView])
                mainStackView.axis = .vertical
                mainStackView.spacing = 8 // Spacing between image and text block
                mainStackView.translatesAutoresizingMaskIntoConstraints = false

                contentView.addSubview(mainStackView)

                // --- Constraints ---
                NSLayoutConstraint.activate([
                    // ImageView constraints (make it stretch edge to edge horizontally within the stackview)
                     newsImageView.heightAnchor.constraint(equalTo: newsImageView.widthAnchor, multiplier: 0.6), // Maintain an aspect ratio (e.g., 16:9. Adjust multiplier as needed)

                    // Main StackView constraints (pin to contentView edges with padding)
                    mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
                    mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
                    mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
                    mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
                ])
                 // Lower priority constraint to allow shrinking if needed
                 let heightConstraint = newsImageView.heightAnchor.constraint(equalToConstant: 150) // Example fixed height
                 heightConstraint.priority = .defaultHigh // Allow aspect ratio to take precedence if possible
                 heightConstraint.isActive = true
            }

            // --- Update shadow path when layout changes ---
            override func layoutSubviews() {
                super.layoutSubviews()
                // Update the shadow path to match the current bounds and corner radius
                // Ensures shadow is correct if cell size changes (e.g., rotation)
                if bounds != .zero { // Avoid calculation when bounds are zero during setup
                     layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: contentView.layer.cornerRadius).cgPath
                }
            }

            // Configures the cell with an article
            func configure(with article: ViewController.Article) {
                titleLabel.text = article.title ?? "No Title Available"
                descriptionLabel.text = article.description ?? "No Description Available"
                
                // Set placeholder image before loading starts
                newsImageView.image = UIImage(systemName: "photo.fill") // Use a system placeholder
                newsImageView.backgroundColor = .secondarySystemBackground // Give placeholder a background

                // Load image from URL asynchronously
                if let imageUrlString = article.urlToImage, let url = URL(string: imageUrlString) {
                    loadImage(from: url)
                } else {
                     // Keep the placeholder if no URL
                    newsImageView.image = UIImage(systemName: "photo.fill")
                    newsImageView.backgroundColor = .secondarySystemBackground
                }
            }
            
            // Loads the image asynchronously from a URL
            private func loadImage(from url: URL) {
                // Use URLSession for better control and caching (optional but recommended)
                let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                    guard let self = self else { return }
                    
                    // Check for errors and ensure data is valid image data
                    if error == nil, let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            // Check if the cell is still configured for the same URL (or article)
                            // to prevent displaying the wrong image if the cell is reused quickly.
                            // You might need to store the 'url' in the cell and compare.
                            self.newsImageView.image = image
                            self.newsImageView.backgroundColor = .clear // Remove placeholder background
                        }
                    } else {
                        // Handle image loading error (keep placeholder)
                        DispatchQueue.main.async {
                           self.newsImageView.image = UIImage(systemName: "photo.fill") // Or an error placeholder
                           self.newsImageView.backgroundColor = .secondarySystemBackground
                        }
                        print("Error loading image from \(url): \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
                task.resume()
            }

            // Prepare for reuse - reset content
             override func prepareForReuse() {
                 super.prepareForReuse()
                 newsImageView.image = nil // Clear image
                 titleLabel.text = nil     // Clear text
                 descriptionLabel.text = nil // Clear text
                 // Cancel any ongoing image loading task if you manage tasks more directly
             }
        }
        
        // MARK: - DetailViewController (For News Details)
        class DetailViewController: UIViewController {
            var article: ViewController.Article?
            
            // --- UI Elements (Declare as properties for easier access) ---
            let scrollView = UIScrollView()
            let contentView = UIView() // Content view inside scroll view
            let imageView = UIImageView()
            let titleLabel = UILabel()
            let descriptionLabel = UILabel()
            // Add a button to open the article in Safari (optional)
            let readMoreButton = UIButton(type: .system)

            override func viewDidLoad() {
                super.viewDidLoad()
                view.backgroundColor = .systemBackground // Use system background
                setupUI()
                configureUI()
            }
            
            func setupUI() {
                // --- ScrollView Setup ---
                scrollView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(scrollView)
                
                // --- ContentView Setup ---
                contentView.translatesAutoresizingMaskIntoConstraints = false
                scrollView.addSubview(contentView)
                
                // --- ImageView Setup ---
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.backgroundColor = .secondarySystemBackground // Placeholder background
                contentView.addSubview(imageView)
                
                // --- TitleLabel Setup ---
                titleLabel.translatesAutoresizingMaskIntoConstraints = false
                titleLabel.font = UIFont.boldSystemFont(ofSize: 24) // Larger title
                titleLabel.numberOfLines = 0 // Allow multiple lines
                contentView.addSubview(titleLabel)
                
                // --- DescriptionLabel Setup ---
                descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
                descriptionLabel.font = UIFont.systemFont(ofSize: 18)
                descriptionLabel.numberOfLines = 0 // Allow multiple lines
                descriptionLabel.textColor = .secondaryLabel // Slightly dimmer text
                contentView.addSubview(descriptionLabel)

                // --- Read More Button Setup ---
                readMoreButton.translatesAutoresizingMaskIntoConstraints = false
                readMoreButton.setTitle("Read Full Article", for: .normal)
                readMoreButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
                readMoreButton.addTarget(self, action: #selector(openArticleLink), for: .touchUpInside)
                readMoreButton.isHidden = article?.url == nil // Hide if no URL
                contentView.addSubview(readMoreButton)
                
                // --- Layout Constraints ---
                let padding: CGFloat = 16
                NSLayoutConstraint.activate([
                    // ScrollView constraints (pin to view edges)
                    scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                    scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                    
                    // ContentView constraints (pin to scroll view content layout guide and width guide)
                    contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                    contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                    contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                    contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                    contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor), // Important for vertical scrolling

                    // ImageView constraints
                    imageView.topAnchor.constraint(equalTo: contentView.topAnchor), // Pin to top
                    imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                    imageView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.6), // Aspect ratio

                    // TitleLabel constraints
                    titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: padding),
                    titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
                    titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
                    
                    // DescriptionLabel constraints
                    descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: padding / 2),
                    descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
                    descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
                   // descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding) // Pin to bottom

                    // Read More Button constraints
                    readMoreButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: padding),
                    readMoreButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
                    readMoreButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
                    readMoreButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding) // Pin button to bottom
                ])
            }
            
            func configureUI() {
                guard let article = article else { return }
                
                title = article.title ?? "News Details" // Set navigation bar title too
                
                titleLabel.text = article.title ?? "No Title Available"
                descriptionLabel.text = article.description ?? "No Description Available"
                 readMoreButton.isHidden = article.url == nil // Ensure button state is correct

                // Load article image asynchronously
                if let imageUrlString = article.urlToImage, let url = URL(string: imageUrlString) {
                    // Use a similar loadImage helper function if desired
                    DispatchQueue.global().async {
                        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                            DispatchQueue.main.async { [weak self] in
                                self?.imageView.image = image
                                self?.imageView.backgroundColor = .clear
                            }
                        } else {
                             DispatchQueue.main.async { [weak self] in
                                self?.imageView.image = UIImage(systemName: "photo.fill") // Error/fallback placeholder
                            }
                        }
                    }
                } else {
                    imageView.image = UIImage(systemName: "photo.fill") // Placeholder if no URL
                }
            }

            @objc func openArticleLink() {
                guard let urlString = article?.url, let url = URL(string: urlString) else {
                    print("Error: Article URL is missing or invalid.")
                    // Optionally show an alert to the user
                    let alert = UIAlertController(title: "Cannot Open Link", message: "The link to the full article is not available.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                    return
                }

                 // Check if the URL can be opened
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    print("Error: Cannot open URL: \(url)")
                     let alert = UIAlertController(title: "Cannot Open Link", message: "Unable to open the article link.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    
    func requestAuthorizationAndQuerySteps() {
            // 1. Check if step counting is available on this device
            guard CMPedometer.isStepCountingAvailable() else {
                print("Step counting is not available on this device.")
                DispatchQueue.main.async {
                    self.stepCountLabel.text = "Steps N/A"
                }
                return
            }

            // 2. Check current authorization status
            let authorizationStatus = CMPedometer.authorizationStatus()

            switch authorizationStatus {
            case .notDetermined:
                // Permission hasn't been asked yet. Querying steps will trigger the request.
                print("Permission not determined. Querying steps will request authorization.")
                queryTodaysSteps()
            case .authorized:
                // Permission already granted.
                print("Permission authorized.")
                queryTodaysSteps()
            case .denied, .restricted:
                // Permission denied or restricted by parental controls.
                print("Permission denied or restricted.")
                DispatchQueue.main.async {
                    self.stepCountLabel.text = "Permission Denied"
                    // Optionally, guide the user to Settings
                    self.showSettingsAlert()
                }
            @unknown default:
                print("Unknown authorization status.")
                DispatchQueue.main.async {
                    self.stepCountLabel.text = "Error"
                }
            }
        }

        func queryTodaysSteps() {
            // Define the time range for today's steps
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now) // Gets 12:00 AM today

            print("Querying steps from \(startOfDay) to \(now)")

            // Query the pedometer for step data
            pedometer.queryPedometerData(from: startOfDay, to: now) { [weak self] (pedometerData, error) in
                // Ensure execution is on the main thread for UI updates
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    // 3. Handle errors
                    if let error = error {
                        print("Error querying pedometer data: \(error.localizedDescription)")
                        self.stepCountLabel.text = "Error Fetching"
                        // Check if the error is due to authorization after the initial check
                        if (error as NSError).domain == CMErrorDomain && (error as NSError).code == CMErrorMotionActivityNotAuthorized.rawValue {
                             print("Authorization was denied during query.")
                             self.stepCountLabel.text = "Permission Denied"
                             self.showSettingsAlert()
                        }
                        return
                    }

                    // 4. Handle the pedometer data
                    if let data = pedometerData {
                        let steps = data.numberOfSteps.intValue
                        print("Successfully fetched steps: \(steps)")
                        self.stepCountLabel.text = "\(steps) Steps Today"
                    } else {
                        print("Pedometer data was nil, but no error.")
                        self.stepCountLabel.text = "No Data"
                    }
                }
            }
        }

        // Helper function to guide user to Settings if permission denied
        func showSettingsAlert() {
             DispatchQueue.main.async { // Ensure UI updates are on the main thread
                let alert = UIAlertController(
                    title: "Permission Required",
                    message: "This app needs permission to access motion data to count steps. Please grant permission in Settings.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                    // Open app settings
                    if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                })
                self.present(alert, animated: true)
            }
        }

        // --- Example of fetching historical data (e.g., last 7 days) ---
        func queryLastSevenDaysSteps() {
            let calendar = Calendar.current
            let endDate = Date() // Today
            guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
                 print("Error calculating start date")
                 return
            }

             print("Querying steps from \(startDate) to \(endDate)")

             pedometer.queryPedometerData(from: startDate, to: endDate) { pedometerData, error in
                 DispatchQueue.main.async {
                     if let error = error {
                         print("Error querying last 7 days steps: \(error.localizedDescription)")
                         // Handle error appropriately
                         return
                     }
                     if let data = pedometerData {
                         let totalSteps = data.numberOfSteps.intValue
                         print("Total steps in the last 7 days: \(totalSteps)")
                         // Update UI or store data as needed
                         // self.stepCountLabel.text = "\(totalSteps) Steps (7 Days)"
                     }
                 }
             }
        }
    }

    
    
    
    
     // End of ViewController class
