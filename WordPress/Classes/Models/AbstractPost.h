#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "BasePost.h"

NS_ASSUME_NONNULL_BEGIN

@class Media;
@class Comment;

typedef NS_ENUM(NSUInteger, AbstractPostRemoteStatus) {
    AbstractPostRemoteStatusPushing,    // Uploading post
    AbstractPostRemoteStatusFailed,      // Upload failed
    AbstractPostRemoteStatusLocal,       // Only local version
    AbstractPostRemoteStatusSync,       // Post uploaded
    AbstractPostRemoteStatusPushingMedia, // Push Media
    AbstractPostRemoteStatusAutoSaved,       // Post remote auto-saved

    // All the previous states were deprecated in 24.7 and are no longer used
    // by the app. To get the status of the uploads, use `PostCoordinator`.

    /// The default state of the newly created local revision.
    AbstractPostRemoteStatusLocalRevision,
    /// The user saved the revision, and it needs to be uploaded to a server.
    AbstractPostRemoteStatusSyncNeeded
};

@interface AbstractPost : BasePost

// Relationships
@property (nonatomic, strong) Blog *blog;
@property (nonatomic, strong, nullable) NSDate * dateModified;
@property (nonatomic, strong) NSSet<Media *> *media;
@property (weak, readonly) AbstractPost *original;
@property (weak, readonly) AbstractPost *revision;
@property (nonatomic, strong) NSSet *comments;
@property (nonatomic, strong, nullable) Media *featuredImage;

// By convention these should be treated as read only and not manually set.
// These are primarily used as helpers sorting fetchRequests.
@property (nonatomic, assign) BOOL metaIsLocal;
@property (nonatomic, assign) BOOL metaPublishImmediately;
/**
 This array will contain a list of revision IDs.
 */
@property (nonatomic, strong, nullable) NSArray *revisions;
/**
 The default value of autoUploadAttemptsCount is 0.
*/
@property (nonatomic, strong, nonnull) NSNumber *autoUploadAttemptsCount;

/**
 Autosave attributes hold a snapshot of the post's content.
 */
@property (nonatomic, copy, nullable) NSString *autosaveContent;
@property (nonatomic, copy, nullable) NSString *autosaveExcerpt;
@property (nonatomic, copy, nullable) NSString *autosaveTitle;
@property (nonatomic, copy, nullable) NSDate *autosaveModifiedDate;
@property (nonatomic, copy, nullable) NSNumber *autosaveIdentifier;

/// Used to deduplicate new posts
@property (nonatomic, strong, nullable) NSUUID *foreignID;

/// - warning: deprecated (kahu-offline-mode)
@property (nonatomic, strong, nullable) NSString *confirmedChangesHash;
@property (nonatomic, strong, nullable) NSDate *confirmedChangesTimestamp;

// Revision management
- (AbstractPost *)createRevision;
/// A new version of `createRevision` that allows you to create revisions based
/// on other revisions.
/// 
/// - warning: Work-in-progress (kahu-offline-mode)
- (AbstractPost *)_createRevision;
- (void)deleteRevision;
- (void)applyRevision;
- (AbstractPost *)updatePostFrom:(AbstractPost *)revision;
- (BOOL)isRevision;
- (BOOL)isOriginal;

/// Returns the latest revision of a post.
///
- (AbstractPost *)latest;
- (AbstractPost *)cloneFrom:(AbstractPost *)source;
- (BOOL)hasSiteSpecificChanges;
- (BOOL)hasPhoto;
- (BOOL)hasVideo;
- (BOOL)hasCategories;
- (BOOL)hasTags;

/// - note: deprecated (kahu-offline-mode)
@property (nonatomic, assign, readonly) BOOL isFailed;

@property (nonatomic, assign, readonly) BOOL hasFailedMedia;

/**
 *  @brief      Call this method to know whether this post has a revision or not.
 *
 *  @returns    YES if this post has a revision, NO otherwise.
 */
- (BOOL)hasRevision;

#pragma mark - Conveniece Methods
/// - note: deprecated (kahu-offline-mode)
- (void)publishImmediately;
/// - note: deprecated (kahu-offline-mode)
- (BOOL)shouldPublishImmediately;
- (NSString *)authorNameForDisplay;
- (NSString *)blavatarForDisplay;
- (NSString *)dateStringForDisplay;
- (BOOL)isMultiAuthorBlog;
- (BOOL)isPrivateAtWPCom;
- (BOOL)supportsStats;


#pragma mark - Unsaved Changes

/**
 *  @brief      Wether the post can be saved or not.
 *
 *  @returns    YES if the post can be saved, NO otherwise.
 */
- (BOOL)canSave;

/**
 *  @brief      Call this method to know if the post has either local or remote unsaved changes.
 *  @details    There should be no need to override this method.  Consider overriding
 *              methods hasLocalChanges and hasRemoteChanges instead.
 *  @returns    YES if there are unsaved changes, NO otherwise.
 */
- (BOOL)hasUnsavedChanges;

/**
 *  @brief      Call this method to know if the post has remote changes.
 *  @returns    YES if there are unsaved changes, NO otherwise.
 */
- (BOOL)hasRemoteChanges;

/**
 An array of statuses available to a post while editing
 @details Subset of status a user may assign to a post they are editing.
 Status included are: draft, pending, and publish.
 Private is not listed as this is determined by the visibility settings.
 Scheduled is not listed as this should be handled by assigning a
 future date.
 Trash is not listed as this should be handled via a delete action.
 */
- (NSArray *)availableStatusesForEditing;


/**
 Returns the correct "publish" status for the current value of date_created_gmt.
 Future dates return PostStatusScheduled. Otherwise PostStatusPublish. This is not
 necessarily the current value of `status`
 */
- (NSString *)availableStatusForPublishOrScheduled;

/**
 Returns YES if the post is has a `future` post status
 */
- (BOOL)isScheduled;

/**
 Returns YES if the post is a draft
 */
- (BOOL)isDraft;

/**
 Returns YES if the post is a published.
 */
- (BOOL)isPublished;

/**
 Returns YES if the original post is a draft
 */
/// - note: deprecated (kahu-offline-mode)
- (BOOL)originalIsDraft;

/**
 Returns YES if the post has a future date_created_gmt.
 This is different from "isScheduled" in that  a post with a draft, pending, or
 trashed status can also have a date_created_gmt with a future value.
 */
/// - note: deprecated (kahu-offline-mode)
- (BOOL)hasFuturePublishDate;

/**
 Returns YES if dateCreated is nil, or if dateCreated and dateModified are equal.
 Used when determining if a post should publish immediately.
 */
/// - note: deprecated (kahu-offline-mode)
- (BOOL)dateCreatedIsNilOrEqualToDateModified;

/**
 *  Whether there was any attempt ever to upload this post, either successful or failed.
 *
 *  @returns    YES if there ever was an attempt to upload this post, NO otherwise.
 */
/// - warning: deprecated (kahu-offline-mode)
- (BOOL)hasNeverAttemptedToUpload;

/**
 *  Whether the post has local changes or not.  Local changes are all changes that are have not been
 *  published to the server yet.
 *
 *  @returns    YES if the post has local changes, NO otherwise.
 */
- (BOOL)hasLocalChanges;

// Does the post exist on the blog?
- (BOOL)hasRemote;
// Deletes post locally
- (void)remove;
// Save changes to disk
- (void)save;

// This property is used to indicate whether an app should attempt to automatically retry upload this post
// the next time a internet connection is available.
@property (nonatomic, assign) BOOL shouldAttemptAutoUpload;

// This property tracks whether a file's attempt to auto-upload was manually cancelled by the user.
@property (nonatomic, assign, readonly) BOOL wasAutoUploadCancelled;


/**
 * Updates the path for the display image by looking at the post content and trying to find an good image to use.
 * If no appropiated image is found the path is set to nil.
 */
- (void)updatePathForDisplayImageBasedOnContent;

@end

@interface AbstractPost (CoreDataGeneratedAccessors)

- (void)addMediaObject:(Media *)value;
- (void)removeMediaObject:(Media *)value;
- (void)addMedia:(NSSet *)values;
- (void)removeMedia:(NSSet *)values;

- (void)addCommentsObject:(Comment *)value;
- (void)removeCommentsObject:(Comment *)value;
- (void)addComments:(NSSet *)values;
- (void)removeComments:(NSSet *)values;

@end

NS_ASSUME_NONNULL_END
