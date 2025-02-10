import UIKit

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    var collectionView: UICollectionView!
    let items = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6", "Item 7", "Item 8", "Item 9", "Item 10"]

    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground // Use system background for light/dark mode support
           title = "Home" // Set the title that will appear on the tab
           // Add any other setup for your Home view here
           let label = UILabel()
           label.text = "Home View"
           label.translatesAutoresizingMaskIntoConstraints = false
           view.addSubview(label)
           NSLayoutConstraint.activate([
               label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
               label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
           ])
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.frame.width - 20, height: 100)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
        view.addSubview(collectionView)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
 
        if let tabBar = self.tabBarController?.tabBar { // Safely unwrap the tab bar
            NSLayoutConstraint.activate([
                collectionView.topAnchor.constraint(equalTo: view.topAnchor),
                collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                collectionView.bottomAnchor.constraint(equalTo: tabBar.topAnchor) // Constrain to *above* the tab bar
            ])
        } else { // Handle the case where there is no tab bar
            NSLayoutConstraint.activate([
                collectionView.topAnchor.constraint(equalTo: view.topAnchor),
                collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }}

    // MARK: - UICollectionViewDataSource (These methods MUST be implemented)

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeedCell", for: indexPath) as! FeedCell
        cell.configure(with: items[indexPath.row])
        return cell
    }

    // MARK: - UICollectionViewDelegate (Optional, but often useful)

    // Example delegate method (you can add more as needed)
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Selected item at index: \(indexPath.row)")
        // Handle item selection here
    }
}

class FeedCell: UICollectionViewCell {

    let label = UILabel() // Example label

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    func setupViews() {
        // Add and configure your cell's subviews (labels, images, etc.)
        label.frame = CGRect(x: 10, y: 10, width: contentView.frame.width - 20, height: 80)
        label.numberOfLines = 0
        contentView.addSubview(label)
        contentView.backgroundColor = .lightGray // Example background color
        layer.cornerRadius = 8 // Example corner radius

    }

    func configure(with item: String) {
        label.text = item
    }
}
