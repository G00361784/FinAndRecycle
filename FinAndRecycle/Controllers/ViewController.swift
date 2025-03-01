import UIKit
import Foundation

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var collectionView: UICollectionView!
    //var collectionView: UICollectionView!
    let items = [
            "Item 1": DetailViewController1(), // Associate item title with a view controller
            "Item 2": DetailViewController2(),
            "Item 3": DetailViewController3(),
            "Item 4": DetailViewController1(), // Example of reusing view controllers
            "Item 5": DetailViewController2(),
            "Item 6": DetailViewController3(),
            
        ]
        //let apiKey = "f869c8bcd91543ac9b9689504470c0be"
    
    struct NewsResponse: Codable {
        let articles: [Article]
    }

    struct Article: Codable {
        let title: String?
        let description: String?
        let urlToImage: String?
        // Add other fields as needed
    }

    func fetchNews(completion: @escaping (Result<[Article], Error>) -> Void) {
        let apiKey = "f869c8bcd91543ac9b9689504470c0be" 
        let urlString = "https://newsapi.org/v2/everything?q=oceanenviroment&apiKey=\(apiKey)" // Example endpoint

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }

            do {
                let decoder = JSONDecoder()
                let newsResponse = try decoder.decode(NewsResponse.self, from: data)
                completion(.success(newsResponse.articles))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Example usage:
    
    
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            title = "Home"
            
            fetchNews { result in
                switch result {
                case .success(let articles):
                    for article in articles {
                        print(article.title ?? "No Title")
                    }
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
            
            let layout = UICollectionViewFlowLayout()
            layout.itemSize = CGSize(width: 200, height: 100)
            layout.minimumInteritemSpacing = 10
            layout.minimumLineSpacing = 10
            layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

            collectionView.collectionViewLayout = layout
            collectionView.backgroundColor = .white
            collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
            collectionView.dataSource = self
            collectionView.delegate = self

            DispatchQueue.main.async {
                self.scrollView.contentSize = self.collectionView.contentSize
            }
        }

        // MARK: - UICollectionViewDataSource

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return 1
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return items.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeedCell", for: indexPath) as! FeedCell
            let itemTitle = Array(items.keys)[indexPath.row] // Get the item title
            cell.configure(with: itemTitle, target: self, action: #selector(buttonTapped(_:)))
            cell.button.tag = indexPath.row
            return cell
        }

        // MARK: - Button Action
        @objc func buttonTapped(_ sender: UIButton) {
            let index = sender.tag
            let itemTitle = Array(items.keys)[index]
            let destinationVC = items[itemTitle]! // Get the associated view controller

            print("Button tapped at index: \(index)")
            print("Selected item: \(itemTitle)")

            navigationController?.pushViewController(destinationVC, animated: true)
        }
    }

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

        func configure(with item: String, target: Any?, action: Selector?) {
            button.setTitle(item, for: .normal)
            button.addTarget(target, action: action!, for: .touchUpInside)
        }
    }


    // Example Detail View Controllers (Create as many as you need)

    class DetailViewController1: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .white
            title = "Details 1"  // Set a specific title
            let label = UILabel(frame: view.bounds)
            label.text = "Detail View 1"
            label.textAlignment = .center
            view.addSubview(label)
        }
    }

    class DetailViewController2: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .white
            title = "Details 2" // Set a specific title
            let label = UILabel(frame: view.bounds)
            label.text = "Detail View 2"
            label.textAlignment = .center
            view.addSubview(label)
        }
    }

    class DetailViewController3: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .white
            title = "Details 3" // Set a specific title
            let label = UILabel(frame: view.bounds)
            label.text = "Detail View 3"
            label.textAlignment = .center
            view.addSubview(label)
        }
    }
