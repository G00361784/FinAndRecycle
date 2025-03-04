import UIKit
import Foundation

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    // Stores fetched news articles
    var articles: [Article] = []
    
    // API key for accessing the News API
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
    }
    
    // MARK: - ViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "News Feed"
        
        // Setup the collection view layout and register cells
        setupCollectionView()
        
        // Fetch news articles from the API
        fetchNews()
    }
    
    // MARK: - CollectionView Setup
    
    func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10  // Spacing between items
        layout.minimumLineSpacing = 10       // Spacing between lines
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        // Adjust item size based on the screen width
        layout.itemSize = CGSize(width: view.frame.width - 20, height: 200)
        
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColor = .white
        
        // Register custom cell for the collection view
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
        
        // Set data source and delegate
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    // MARK: - Fetching News from API
    
    func fetchNews() {
        let query = "Ocean Environment" // Search query for news
        let urlString = "https://newsapi.org/v2/everything?q=\(query)&language=en&sortBy=publishedAt&apiKey=\(apiKey)"
        
        // Convert the string into a URL
        guard let url = URL(string: urlString) else { return }
        
        // Create a data task to fetch the news
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error)") // Print error if request fails
                return
            }
            
            // Ensure data was received
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                // Decode the JSON response into NewsResponse struct
                let decoder = JSONDecoder()
                let newsResponse = try decoder.decode(NewsResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.articles = newsResponse.articles // Store articles
                    self.collectionView.reloadData() // Reload collection view to display articles
                }
            } catch {
                print("Decoding error: \(error)") // Print error if JSON parsing fails
            }
        }.resume() // Start the network request
    }
    
    // MARK: - UICollectionViewDataSource
    
    // Returns the number of articles to be displayed
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return articles.count
    }
    
    // Creates and configures a cell for each article
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeedCell", for: indexPath) as! FeedCell
        let article = articles[indexPath.row] // Get the article at this index
        cell.configure(with: article) // Configure the cell with article data
        return cell
    }
    
    // Handles user tapping on a news item
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedArticle = articles[indexPath.row]
        let detailVC = DetailViewController()
        detailVC.article = selectedArticle
        
        // Navigate to the details screen
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    // MARK: - FeedCell (Custom Collection View Cell)
    class FeedCell: UICollectionViewCell {
        let newsImageView = UIImageView()  // Image of the news article
        let titleLabel = UILabel()         // Title of the article
        let descriptionLabel = UILabel()   // Short description of the article
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupViews() // Setup the cell UI
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            setupViews()
        }
        
        // Setup UI elements inside the cell
        func setupViews() {
            contentView.backgroundColor = .white
            contentView.layer.cornerRadius = 8
            contentView.layer.shadowColor = UIColor.black.cgColor
            contentView.layer.shadowOpacity = 0.1
            contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
            contentView.layer.shadowRadius = 4
            
            newsImageView.contentMode = .scaleAspectFill
            newsImageView.clipsToBounds = true
            newsImageView.layer.cornerRadius = 8
            
            titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
            titleLabel.numberOfLines = 2
            
            descriptionLabel.font = UIFont.systemFont(ofSize: 14)
            descriptionLabel.numberOfLines = 3
            descriptionLabel.textColor = .gray
            
            let stackView = UIStackView(arrangedSubviews: [newsImageView, titleLabel, descriptionLabel])
            stackView.axis = .vertical
            stackView.spacing = 8
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            contentView.addSubview(stackView)
            
            // Constraints for stackView
            newsImageView.heightAnchor.constraint(equalToConstant: 120).isActive = true
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10).isActive = true
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10).isActive = true
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
        }
        
        // Configures the cell with an article
        func configure(with article: ViewController.Article) {
            titleLabel.text = article.title ?? "No Title"
            descriptionLabel.text = article.description ?? "No Description"
            
            // Load image from URL
            if let imageUrl = article.urlToImage, let url = URL(string: imageUrl) {
                loadImage(from: url)
            } else {
                newsImageView.image = UIImage(systemName: "photo") // Default placeholder
            }
        }
        
        // Loads the image asynchronously from a URL
        private func loadImage(from url: URL) {
            DispatchQueue.global().async {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.newsImageView.image = image
                    }
                }
            }
        }
    }
    
    // MARK: - DetailViewController (For News Details)
    class DetailViewController: UIViewController {
        var article: ViewController.Article?
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .white
            title = article?.title ?? "News Details"
            
            let scrollView = UIScrollView()
            let contentView = UIView()
            let imageView = UIImageView()
            let titleLabel = UILabel()
            let descriptionLabel = UILabel()
            
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            contentView.translatesAutoresizingMaskIntoConstraints = false
            imageView.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
            
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            
            // Load article image
            if let imageUrl = article?.urlToImage, let url = URL(string: imageUrl) {
                DispatchQueue.global().async {
                    if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            imageView.image = image
                        }
                    }
                }
            }
            
            titleLabel.text = article?.title ?? "No Title"
            titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
            titleLabel.numberOfLines = 0
            
            descriptionLabel.text = article?.description ?? "No Description"
            descriptionLabel.numberOfLines = 0
            descriptionLabel.font = UIFont.systemFont(ofSize: 18)
            
            contentView.addSubview(imageView)
            contentView.addSubview(titleLabel)
            contentView.addSubview(descriptionLabel)
            
            scrollView.addSubview(contentView)
            view.addSubview(scrollView)
        }
    }
}
