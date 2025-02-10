import UIKit

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    //var collectionView: UICollectionView!
        let items = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6", "Item 7", "Item 8", "Item 9", "Item 10"]
            let logoImageView = UIImageView()  // Logo image view
            let tabBar = UITabBar() // Or your custom tab bar view. If you use a UITabBarController, you likely won't need this.

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Home"
        
        // 1. Set up Scroll View
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor) // Important: Scroll view fills the main view
        ])
        
        
        // 2. Add Logo Image View
        logoImageView.image = UIImage(named: "your_logo_image") // Replace with your logo image
        logoImageView.contentMode = .scaleAspectFit // Or .scaleAspectFill, etc.
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(logoImageView)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20), // Adjust top margin
            logoImageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            logoImageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            logoImageView.heightAnchor.constraint(equalToConstant: 80) // Adjust height as needed
        ])
        
        // 3. Add Collection View
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.frame.width - 20, height: 100)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        
        //collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout) // Initialize here if not using an IBOutlet
        collectionView.backgroundColor = .white
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false // VERY IMPORTANT
        scrollView.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20), // Space below logo
            collectionView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: view.frame.height * 0.6) // Adjust as needed
        ])
        
        
        // 4. Add Tab Bar (If NOT using a UITabBarController)
        // If you are using a UITabBarController, you likely do NOT need this code.
        // Instead, just embed this ViewController in the UITabBarController.
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(tabBar) // Add to scroll view!
        
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 20), // Space below collection view
            tabBar.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 49) // Standard tab bar height
        ])
        
        // 5. Set Scroll View Content Size (Crucial!)
        // Calculate the total height of all your subviews within the scroll view.
        // This is a simplified example. You might need to adjust based on your layout.
        scrollView.contentSize = CGSize(width: view.frame.width, height: logoImageView.frame.height + collectionView.frame.height + tabBar.frame.height + 40) // Add up heights and margins
    }
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
