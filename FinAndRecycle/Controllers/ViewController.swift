import UIKit

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var collectionView: UICollectionView!
    //var collectionView: UICollectionView!
    let items = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6", "Item 7", "Item 8", "Item 9", "Item 10"]

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            title = "Home"

            let layout = UICollectionViewFlowLayout()
            layout.itemSize = CGSize(width: 200, height: 100) // Adjust as needed
            layout.minimumInteritemSpacing = 10
            layout.minimumLineSpacing = 10
            layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

            collectionView.collectionViewLayout = layout // No need for conditional creation
            collectionView.backgroundColor = .white
            collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
            collectionView.dataSource = self
            collectionView.delegate = self

           
            DispatchQueue.main.async { // Ensure layout is complete
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
            cell.configure(with: items[indexPath.row], target: self, action: #selector(buttonTapped(_:)))
            cell.button.tag = indexPath.row // Set the tag to identify the button
            return cell
        }


        // MARK: - Button Action
        @objc func buttonTapped(_ sender: UIButton) {
            let index = sender.tag
            print("Button tapped at index: \(index)")
            
            let selectedItem = items[index]
            print("Selected item: \(selectedItem)")

           
            let newVC = DetailViewController() // Replace with your actual view controller
            newVC.item = selectedItem // Pass the selected item if needed
            navigationController?.pushViewController(newVC, animated: true)
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
            button.frame = contentView.bounds // Button fills the cell
            button.setTitleColor(.black, for: .normal) // Set title color
            button.backgroundColor = .lightGray
            contentView.addSubview(button)
            button.layer.cornerRadius = 8
        }

        func configure(with item: String, target: Any?, action: Selector?) {
            button.setTitle(item, for: .normal)
            button.addTarget(target, action: action!, for: .touchUpInside)
        }
    }

    class DetailViewController: UIViewController {
        var item: String?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .white
            title = "Details"

            let label = UILabel(frame: view.bounds)
            label.text = item
            label.textAlignment = .center
            view.addSubview(label)
        }
    }
