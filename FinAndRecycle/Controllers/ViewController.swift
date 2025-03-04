import UIKit
import Foundation

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var collectionView: UICollectionView!
        
        var articles: [Article] = []  // Store fetched articles
        private let apiKey = "f869c8bcd91543ac9b9689504470c0be"
        
        struct NewsResponse: Codable {
            let articles: [Article]
        }
        
        struct Article: Codable {
            let title: String?
            let description: String?
            let urlToImage: String?
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            title = "News Feed"
            
            setupCollectionView()
            fetchNews()
        }
        
        func setupCollectionView() {
            let layout = UICollectionViewFlowLayout()
            layout.minimumInteritemSpacing = 10
            layout.minimumLineSpacing = 10
            layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            layout.itemSize = CGSize(width: view.frame.width - 20, height: 200) // Adjust width & height
            
            collectionView.collectionViewLayout = layout
            collectionView.backgroundColor = .white
            collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
            collectionView.dataSource = self
            collectionView.delegate = self
        }
        
        func fetchNews() {
            let query = "Ocean Environment"
            let urlString = "https://newsapi.org/v2/everything?q=\(query)&language=en&sortBy=publishedAt&apiKey=\(apiKey)"
            
            guard let url = URL(string: urlString) else { return }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("Error: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let newsResponse = try decoder.decode(NewsResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.articles = newsResponse.articles
                        self.collectionView.reloadData()
                    }
                } catch {
                    print("Decoding error: \(error)")
                }
            }.resume()
        }
        
        // MARK: - UICollectionViewDataSource
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return articles.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeedCell", for: indexPath) as! FeedCell
            let article = articles[indexPath.row]
            cell.configure(with: article)
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let selectedArticle = articles[indexPath.row]
            let detailVC = DetailViewController()
            detailVC.article = selectedArticle
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }

    // MARK: - FeedCell (Collection View Cell)
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
            setupViews()
        }
        
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
            
            // Constraints
            newsImageView.heightAnchor.constraint(equalToConstant: 120).isActive = true
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10).isActive = true
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10).isActive = true
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
        }
        
        func configure(with article: ViewController.Article) {
            titleLabel.text = article.title ?? "No Title"
            descriptionLabel.text = article.description ?? "No Description"
            
            if let imageUrl = article.urlToImage, let url = URL(string: imageUrl) {
                loadImage(from: url)
            } else {
                newsImageView.image = UIImage(systemName: "photo") // Placeholder
            }
        }
        
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
