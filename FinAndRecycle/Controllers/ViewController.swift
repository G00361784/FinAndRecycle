import UIKit
import Foundation

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var collectionView: UICollectionView!
    //var collectionView: UICollectionView!
    var articles: [Article] = []  // Store fetched articles

        struct NewsResponse: Codable {
            let articles: [Article]
        }

        struct Article: Codable {
            let title: String?
            let description: String?
            let urlToImage: String?
        }

        func fetchNews() {
            let apiKey = "f869c8bcd91543ac9b9689504470c0be"
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
                
            layout.itemSize = CGSize(width: 350, height: 180) // Adjust width and height as needed

            
            collectionView.collectionViewLayout = layout
            collectionView.backgroundColor = .white
            collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
            collectionView.dataSource = self
            collectionView.delegate = self
        }

        // MARK: - UICollectionViewDataSource

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return 1
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return articles.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeedCell", for: indexPath) as! FeedCell
            let article = articles[indexPath.row]
            cell.configure(with: article.title ?? "No Title", target: self, action: #selector(articleTapped(_:)))
            cell.button.tag = indexPath.row
            return cell
        }

        // MARK: - Handle Article Tap
        @objc func articleTapped(_ sender: UIButton) {
            let index = sender.tag
            let selectedArticle = articles[index]

            let detailVC = DetailViewController()
            detailVC.article = selectedArticle
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }

    // MARK: - FeedCell (Collection View Cell)
    class FeedCell: UICollectionViewCell {
        let button = UIButton()

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupViews()
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            setupViews()
        }

        func setupViews() {
            button.frame = contentView.bounds
            button.setTitleColor(.black, for: .normal)
            button.backgroundColor = .lightGray
            contentView.addSubview(button)
            button.layer.cornerRadius = 8
        }

        func configure(with title: String, target: Any?, action: Selector?) {
            button.setTitle(title, for: .normal)
            button.addTarget(target, action: action!, for: .touchUpInside)
        }
    }

    // MARK: - DetailViewController (For News Details)
    class DetailViewController: UIViewController {
        var article: ViewController.Article?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .white
            title = article?.title ?? "News Details"

            let label = UILabel(frame: view.bounds)
            label.text = article?.description ?? "No Description"
            label.numberOfLines = 0
            label.textAlignment = .center
            view.addSubview(label)
        }
    }
