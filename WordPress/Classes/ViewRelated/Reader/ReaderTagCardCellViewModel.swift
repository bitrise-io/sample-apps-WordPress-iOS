
class ReaderTagCardCellViewModel: NSObject {

    private typealias DataSource = UICollectionViewDiffableDataSource<Int, NSManagedObjectID>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>

    private weak var parentViewController: UIViewController?
    private let slug: String
    private weak var collectionView: UICollectionView?
    private let isLoggedIn: Bool
    private let cellSize: () -> CGSize?

    private lazy var dataSource: DataSource? = {
        guard let collectionView else {
           return nil
        }
        return DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, objectID in
            guard let post = try? ContextManager.shared.mainContext.existingObject(with: objectID) as? ReaderPost,
                  let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReaderTagCell.classNameWithoutNamespaces(), for: indexPath) as? ReaderTagCell else {
                return UICollectionViewCell()
            }
            cell.configure(parent: self?.parentViewController,
                           post: post,
                           isLoggedIn: self?.isLoggedIn ?? AccountHelper.isLoggedIn)
            return cell
        }
    }()

    private lazy var resultsController: NSFetchedResultsController<ReaderPost> = {
        let fetchRequest = NSFetchRequest<ReaderPost>(entityName: ReaderPost.classNameWithoutNamespaces())
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sortRank", ascending: false)]
        fetchRequest.fetchLimit = Constants.displayPostLimit
        let resultsController = NSFetchedResultsController<ReaderPost>(fetchRequest: fetchRequest,
                                                           managedObjectContext: ContextManager.shared.mainContext,
                                                           sectionNameKeyPath: nil,
                                                           cacheName: nil)
        resultsController.delegate = self
        return resultsController
    }()

    init(parent: UIViewController?, tag: ReaderTagTopic, collectionView: UICollectionView?, isLoggedIn: Bool, cellSize: @escaping @autoclosure () -> CGSize?) {
        self.parentViewController = parent
        self.slug = tag.slug
        self.collectionView = collectionView
        self.isLoggedIn = isLoggedIn
        self.cellSize = cellSize

        super.init()

        resultsController.fetchRequest.predicate = NSPredicate(format: "topic = %@ AND isSiteBlocked = NO", tag)
        collectionView?.delegate = self
    }

    func fetchTagTopics() {
        try? resultsController.performFetch()
    }

    func onTagButtonTapped() {
        let controller = ReaderStreamViewController.controllerWithTagSlug(slug)
        parentViewController?.navigationController?.pushViewController(controller, animated: true)
    }

    struct Constants {
        static let displayPostLimit = 10
    }

}

// MARK: - NSFetchedResultsControllerDelegate

extension ReaderTagCardCellViewModel: NSFetchedResultsControllerDelegate {

    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>,
                    didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        dataSource?.apply(snapshot as Snapshot, animatingDifferences: false)
    }

}

// MARK: - UICollectionViewDelegate

extension ReaderTagCardCellViewModel: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let sectionInfo = resultsController.sections?[safe: indexPath.section],
              indexPath.row < sectionInfo.numberOfObjects else {
            return
        }
        let post = resultsController.object(at: indexPath)
        let controller = ReaderDetailViewController.controllerWithPost(post)
        parentViewController?.navigationController?.pushViewController(controller, animated: true)
    }

}

// MARK: - UICollectionViewDelegateFlowLayout

extension ReaderTagCardCellViewModel: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize() ?? .zero
    }

}
