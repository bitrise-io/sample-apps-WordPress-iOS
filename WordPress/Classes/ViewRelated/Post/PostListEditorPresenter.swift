import Foundation
import UIKit

typealias EditorPresenterViewController = UIViewController & EditorAnalyticsProperties

/// Provide properties for when showing the editor (like type of post, filter, etc)
protocol EditorAnalyticsProperties: AnyObject {
    func propertiesForAnalytics() -> [String: AnyObject]
}

/// Handle a user tapping a post in the post list. If an autosave revision is available, give the
/// user the option through a dialog alert to load the autosave (or just load the regular post) into
/// the editor.
/// Analytics are also tracked.
struct PostListEditorPresenter {

    static func handle(post: Post, in postListViewController: EditorPresenterViewController, entryPoint: PostEditorEntryPoint = .unknown) {
        guard RemoteFeatureFlag.syncPublishing.enabled() else {
            return _handle(post: post, in: postListViewController)
        }

        // Return early if a post is still uploading when the editor's requested.
        guard !PostCoordinator.shared.isUpdating(post) else {
            return // It's clear from the UI that the cells are not interactive
        }

        // No editing posts until the conflict has been resolved.
        if let error = PostCoordinator.shared.syncError(for: post.original()),
           let saveError = error as? PostRepository.PostSaveError,
           case .conflict(let latest) = saveError {
            let post = post.original()
            PostCoordinator.shared.showResolveConflictView(post: post, remoteRevision: latest, source: .postList)
            return
        }

        openEditor(with: post, loadAutosaveRevision: false, in: postListViewController, entryPoint: entryPoint)
    }

    /// - warning: deprecated (kahu-offline-mode)
    private static func _handle(post: Post, in postListViewController: EditorPresenterViewController, entryPoint: PostEditorEntryPoint = .unknown) {
        // Return early if a post is still uploading when the editor's requested.
        guard !PostCoordinator.shared.isUploading(post: post) else {
            presentAlertForPostBeingUploaded()
            return
        }

        // Autosaves are ignored for posts with local changes.
        if !post.hasLocalChanges(), post.hasAutosaveRevision, let saveDate = post.dateModified, let autosaveDate = post.autosaveModifiedDate {
            let autosaveViewController = autosaveOptionsViewController(forSaveDate: saveDate, autosaveDate: autosaveDate, didTapOption: { loadAutosaveRevision in
                openEditor(with: post, loadAutosaveRevision: loadAutosaveRevision, in: postListViewController, entryPoint: entryPoint)
            })
            postListViewController.present(autosaveViewController, animated: true)
        } else {
            openEditor(with: post, loadAutosaveRevision: false, in: postListViewController, entryPoint: entryPoint)
        }
    }

    static func handleCopy(post: Post, in postListViewController: EditorPresenterViewController) {
        // Autosaves are ignored for posts with local changes.
        if !post.hasLocalChanges(), post.hasAutosaveRevision {
            let conflictsResolutionViewController = copyConflictsResolutionViewController(didTapOption: { copyLocal, cancel in
                if cancel {
                    return
                }
                if copyLocal {
                    openEditorWithCopy(with: post, in: postListViewController)
                } else {
                    handle(post: post, in: postListViewController)
                }
            })
            postListViewController.present(conflictsResolutionViewController, animated: true)
        } else {
            openEditorWithCopy(with: post, in: postListViewController)
        }
    }

    private static func openEditor(with post: Post, loadAutosaveRevision: Bool, in postListViewController: EditorPresenterViewController, entryPoint: PostEditorEntryPoint = .unknown) {
        /// This is a workaround for the lack of vie wapperance callbacks send
        /// by `EditPostViewController` due to its weird setup.
        NotificationCenter.default.post(name: .postListEditorPresenterWillShowEditor, object: nil)

        let editor = EditPostViewController(post: post, loadAutosaveRevision: loadAutosaveRevision)
        editor.modalPresentationStyle = .fullScreen
        editor.entryPoint = entryPoint
        editor.onClose = { _ in
            NotificationCenter.default.post(name: .postListEditorPresenterDidHideEditor, object: nil)
        }
        postListViewController.present(editor, animated: false)
    }

    private static func openEditorWithCopy(with post: Post, in postListViewController: EditorPresenterViewController) {
        // Copy Post
        let newPost = post.blog.createDraftPost()
        newPost.postTitle = post.postTitle
        newPost.content = post.content
        newPost.categories = post.categories
        newPost.postFormat = post.postFormat

        openEditor(with: newPost, loadAutosaveRevision: false, in: postListViewController)

        WPAppAnalytics.track(.postListDuplicateAction, withProperties: postListViewController.propertiesForAnalytics(), with: post)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static func dateAndTime(for date: Date) -> String {
        return dateFormatter.string(from: date) + " @ " + timeFormatter.string(from: date)
    }

    /// A dialog giving the user the choice between loading the current version a post or its autosaved version.
    private static func autosaveOptionsViewController(forSaveDate saveDate: Date, autosaveDate: Date, didTapOption: @escaping (_ loadAutosaveRevision: Bool) -> Void) -> UIAlertController {

        let title = NSLocalizedString("Which version would you like to edit?", comment: "Title displayed in popup when user has the option to load unsaved changes")

        let saveDateFormatted = dateAndTime(for: saveDate)
        let autosaveDateFormatted = dateAndTime(for: autosaveDate)
        let message = String(format: NSLocalizedString("You recently made changes to this post but didn't save them. Choose a version to load:\n\nFrom this device\nSaved on %@\n\nFrom another device\nSaved on %@\n", comment: "Message displayed in popup when user has the option to load unsaved changes. \n is a placeholder for a new line, and the two %@ are placeholders for the date of last save on this device, and date of last autosave on another device, respectively."), saveDateFormatted, autosaveDateFormatted)

        let loadSaveButtonTitle = NSLocalizedString("From this device", comment: "Button title displayed in popup indicating date of change on device")
        let fromAutosaveButtonTitle = NSLocalizedString("From another device", comment: "Button title displayed in popup indicating date of change on another device")

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: loadSaveButtonTitle, style: .default) { _ in
            didTapOption(false)
        })
        alertController.addAction(UIAlertAction(title: fromAutosaveButtonTitle, style: .default) { _ in
            didTapOption(true)
        })

        alertController.view.accessibilityIdentifier = "autosave-options-alert"

        return alertController
    }

    /// A dialog giving the user the choice between copying the current version of the post or resolving conflicts with edit.
    private static func copyConflictsResolutionViewController(didTapOption: @escaping (_ copyLocal: Bool, _ cancel: Bool) -> Void) -> UIAlertController {

        let title = NSLocalizedString("Post sync conflict", comment: "Title displayed in popup when user tries to copy a post with unsaved changes")

        let message = NSLocalizedString("The post you are trying to copy has two versions that are in conflict or you recently made changes but didn\'t save them.\nEdit the post first to resolve any conflict or proceed with copying the version from this app.", comment: "Message displayed in popup when user tries to copy a post with conflicts")

        let editFirstButtonTitle = NSLocalizedString("Edit the post first", comment: "Button title displayed in popup indicating that the user edits the post first")
        let copyLocalButtonTitle = NSLocalizedString("Copy the version from this app", comment: "Button title displayed in popup indicating the user copied the local copy")
        let cancelButtonTitle = NSLocalizedString("Cancel", comment: "Cancel button.")

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: editFirstButtonTitle, style: .default) { _ in
            didTapOption(false, false)
        })
        alertController.addAction(UIAlertAction(title: copyLocalButtonTitle, style: .default) { _ in
            didTapOption(true, false)
        })
        alertController.addAction(UIAlertAction(title: cancelButtonTitle, style: .cancel) { _ in
            didTapOption(false, true)
        })

        alertController.view.accessibilityIdentifier = "copy-version-conflict-alert"

        return alertController
    }

    private static func presentAlertForPostBeingUploaded() {
        let message = NSLocalizedString("This post is currently uploading. It won't take long – try again soon and you'll be able to edit it.", comment: "Prompts the user that the post is being uploaded and cannot be edited while that process is ongoing.")

        let alertCancel = NSLocalizedString("OK", comment: "Title of an OK button. Pressing the button acknowledges and dismisses a prompt.")

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addCancelActionWithTitle(alertCancel, handler: nil)
        alertController.presentFromRootViewController()
    }
}

extension Foundation.Notification.Name {
    static let postListEditorPresenterWillShowEditor = Foundation.Notification.Name("org.automattic.postListEditorPresenterWillShowEditor")
    static let postListEditorPresenterDidHideEditor = Foundation.Notification.Name("org.automattic.postListEditorPresenterDidHideEditor")
}
