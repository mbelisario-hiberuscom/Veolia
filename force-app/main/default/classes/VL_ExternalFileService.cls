/**
 * @name VL_ExternalFileService
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Manages the lifecycle of VL_ExternalFile__c traceability records.
 *              All SOQL and DML run with AccessLevel.USER_MODE to enforce FLS.
 */
public with sharing class VL_ExternalFileService {
	private static final String STATUS_PENDING = 'Pending';
	private static final String STATUS_PROCESSING = 'Processing';
	private static final String STATUS_COMPLETED = 'Completed';
	private static final String STATUS_ERROR = 'Error';
	private static final String STATUS_MANUAL_REVIEW = 'Manual Review';

	/**
	 * @name createPendingRecords
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Inserts one Pending VL_ExternalFile__c per transfer request as a single DML.
	 * @param requests List of transfer requests for which traceability records must be created.
	 * @return List<VL_ExternalFile__c> inserted records with Ids populated.
	 */
	public static List<VL_ExternalFile__c> createPendingRecords(List<VL_TransferRequest> requests) {
		if (requests == null || requests.isEmpty()) {
			return new List<VL_ExternalFile__c>();
		}
		List<VL_ExternalFile__c> records = new List<VL_ExternalFile__c>();
		for (VL_TransferRequest req : requests) {
			records.add(buildPending(req));
		}
		Database.insert(records, AccessLevel.USER_MODE);
		return records;
	}

	/**
	 * @name findCompletedKeys
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Returns the set of logical keys that already have a Completed traceability record.
	 * @param logicalKeys Set of logical keys (contentDocumentId:contentVersionId) to check.
	 * @return Set<String> keys already in Completed status.
	 */
	public static Set<String> findCompletedKeys(Set<String> logicalKeys) {
		if (logicalKeys == null || logicalKeys.isEmpty()) {
			return new Set<String>();
		}
		Set<String> completedKeys = new Set<String>();
		for (VL_ExternalFile__c rec : [
			SELECT VL_LogicalKey__c
			FROM VL_ExternalFile__c
			WHERE VL_LogicalKey__c IN :logicalKeys AND VL_Status__c = :STATUS_COMPLETED
			WITH USER_MODE
		]) {
			completedKeys.add(rec.VL_LogicalKey__c);
		}
		return completedKeys;
	}

	/**
	 * @name findUnsyncedDriveItems
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Returns Salesforce Files with Pending, Error, or Manual Review status whose upload destination is the requested Drive folder.
	 *              The destination is resolved through ContentVersion.VL_GoogleDriveFolder_fileupload__c because the
	 *              traceability record stores the ContentVersion Id but does not duplicate the selected folder Id.
	 * @param parentRecordId Salesforce record Id that owns the files.
	 * @param folderId Drive folder currently displayed by the explorer.
	 * @param recordFolderId Drive folder resolved for the Salesforce record; blank upload destinations belong here.
	 * @return List<VL_DriveItemDTO> virtual file cards for unsynchronized files.
	 */
	public static List<VL_DriveItemDTO> findUnsyncedDriveItems(Id parentRecordId, String folderId, String recordFolderId) {
		if (parentRecordId == null || String.isBlank(folderId)) {
			return new List<VL_DriveItemDTO>();
		}

		Set<String> unsyncedStatuses = new Set<String>{ STATUS_PENDING, STATUS_ERROR, STATUS_MANUAL_REVIEW };
		List<VL_ExternalFile__c> traceRecords = [
			SELECT Id, VL_ContentVersionId__c, VL_Status__c, VL_LastErrorTxtArea__c
			FROM VL_ExternalFile__c
			WHERE VL_ParentRecordId__c = :String.valueOf(parentRecordId) AND VL_Status__c IN :unsyncedStatuses
			WITH USER_MODE
			ORDER BY CreatedDate, Id
		];

		Set<Id> contentVersionIds = new Set<Id>();
		for (VL_ExternalFile__c traceRecord : traceRecords) {
			if (String.isNotBlank(traceRecord.VL_ContentVersionId__c)) {
				try {
					contentVersionIds.add(Id.valueOf(traceRecord.VL_ContentVersionId__c));
				} catch (Exception ex) {
					continue;
				}
			}
		}
		if (contentVersionIds.isEmpty()) {
			return new List<VL_DriveItemDTO>();
		}

		Map<Id, ContentVersion> versionsById = new Map<Id, ContentVersion>(
			[
				SELECT Id, Title, FileType, ContentSize, VL_GoogleDriveFolder_fileupload__c
				FROM ContentVersion
				WHERE Id IN :contentVersionIds
				WITH USER_MODE
			]
		);
		Map<String, ContentVersion> versionsByReference = new Map<String, ContentVersion>();
		for (ContentVersion version : versionsById.values()) {
			versionsByReference.put(String.valueOf(version.Id), version);
		}

		List<VL_DriveItemDTO> result = new List<VL_DriveItemDTO>();
		for (VL_ExternalFile__c traceRecord : traceRecords) {
			if (String.isBlank(traceRecord.VL_ContentVersionId__c)) {
				continue;
			}
			ContentVersion version = versionsByReference.get(traceRecord.VL_ContentVersionId__c);
			Boolean hasSelectedFolder = String.isNotBlank(version?.VL_GoogleDriveFolder_fileupload__c);
			Boolean isVisibleDestination = hasSelectedFolder
				? version.VL_GoogleDriveFolder_fileupload__c == folderId
				: folderId == recordFolderId;
			if (version == null || !isVisibleDestination) {
				continue;
			}

			VL_DriveItemDTO item = new VL_DriveItemDTO();
			item.id = 'external-file-' + String.valueOf(traceRecord.Id);
			item.name = version.Title;
			item.isFolder = false;
			item.isLinkedFolder = false;
			item.isReadOnly = false;
			item.mimeType = String.isNotBlank(version.FileType) ? 'application/' + version.FileType.toLowerCase() : 'application/octet-stream';
			item.sizeBytes = version.ContentSize;
			item.syncStatus = traceRecord.VL_Status__c;
			item.syncError = traceRecord.VL_LastErrorTxtArea__c;
			item.externalFileId = String.valueOf(traceRecord.Id);
			result.add(item);
		}
		return result;
	}

	/**
	 * @name getExternalFileStatuses
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Returns the current status and remote identifiers for traceability records belonging to a parent record.
	 * @param parentRecordId Salesforce record Id that owns the files.
	 * @param externalFileIds Traceability record Ids to query in bulk.
	 * @return List<VL_ExternalFileStatusDTO> current synchronization statuses.
	 */
	public static List<VL_ExternalFileStatusDTO> getExternalFileStatuses(Id parentRecordId, Set<Id> externalFileIds) {
		if (parentRecordId == null || externalFileIds == null || externalFileIds.isEmpty()) {
			return new List<VL_ExternalFileStatusDTO>();
		}

		List<VL_ExternalFileStatusDTO> result = new List<VL_ExternalFileStatusDTO>();
		for (VL_ExternalFile__c traceRecord : [
			SELECT Id, VL_Status__c, VL_LastErrorTxtArea__c, VL_RemoteFileId__c, VL_RemoteLinkUrl__c
			FROM VL_ExternalFile__c
			WHERE Id IN :externalFileIds AND VL_ParentRecordId__c = :String.valueOf(parentRecordId)
			WITH USER_MODE
		]) {
			VL_ExternalFileStatusDTO status = new VL_ExternalFileStatusDTO();
			status.externalFileId = String.valueOf(traceRecord.Id);
			status.status = traceRecord.VL_Status__c;
			status.error = traceRecord.VL_LastErrorTxtArea__c;
			status.remoteFileId = traceRecord.VL_RemoteFileId__c;
			status.remoteLinkUrl = traceRecord.VL_RemoteLinkUrl__c;
			result.add(status);
		}
		return result;
	}

	/**
	 * @name markProcessing
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Transitions a traceability record to Processing status.
	 * @param externalFileId Id of the VL_ExternalFile__c record.
	 */
	public static void markProcessing(Id externalFileId) {
		Database.update(new VL_ExternalFile__c(Id = externalFileId, VL_Status__c = STATUS_PROCESSING), AccessLevel.USER_MODE);
	}

	/**
	 * @name markCompleted
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Transitions a traceability record to Completed and stores remote identifiers.
	 * @param externalFileId Id of the VL_ExternalFile__c record.
	 * @param remoteFileId Google Drive file identifier.
	 * @param remoteFolderId Google Drive folder identifier.
	 * @param remoteLinkUrl Shareable web view link.
	 */
	public static void markCompleted(Id externalFileId, String remoteFileId, String remoteFolderId, String remoteLinkUrl) {
		Database.update(
			new VL_ExternalFile__c(
				Id = externalFileId,
				VL_Status__c = STATUS_COMPLETED,
				VL_RemoteFileId__c = remoteFileId,
				VL_RemoteFolderId__c = remoteFolderId,
				VL_RemoteLinkUrl__c = remoteLinkUrl,
				VL_UploadedDate__c = DateTime.now(),
				VL_UploadedByLookup__c = UserInfo.getUserId()
			),
			AccessLevel.USER_MODE
		);
	}

	/**
	 * @name markError
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Transitions a traceability record to Error and stores the diagnostic message.
	 * @param externalFileId Id of the VL_ExternalFile__c record.
	 * @param errorMessage Diagnostic message describing the failure.
	 */
	public static void markError(Id externalFileId, String errorMessage) {
		Database.update(
			new VL_ExternalFile__c(Id = externalFileId, VL_Status__c = STATUS_ERROR, VL_LastErrorTxtArea__c = errorMessage),
			AccessLevel.USER_MODE
		);
	}

	/**
	 * @name markManualReview
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Transitions a traceability record to Manual Review.
	 * @param externalFileId Id of the VL_ExternalFile__c record.
	 * @param reason Reason for manual review.
	 */
	public static void markManualReview(Id externalFileId, String reason) {
		Database.update(
			new VL_ExternalFile__c(Id = externalFileId, VL_Status__c = STATUS_MANUAL_REVIEW, VL_LastErrorTxtArea__c = reason),
			AccessLevel.USER_MODE
		);
	}

	/**
	 * @name incrementRetry
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Increments the retry counter on a traceability record.
	 * @param externalFileId Id of the VL_ExternalFile__c record.
	 */
	public static void incrementRetry(Id externalFileId) {
		VL_ExternalFile__c current = [
			SELECT Id, VL_RetryCountNumber__c
			FROM VL_ExternalFile__c
			WHERE Id = :externalFileId
			WITH USER_MODE
			LIMIT 1
		];
		Integer currentCount = current.VL_RetryCountNumber__c == null ? 0 : (Integer) current.VL_RetryCountNumber__c;
		Database.update(new VL_ExternalFile__c(Id = externalFileId, VL_RetryCountNumber__c = currentCount + 1), AccessLevel.USER_MODE);
	}

	/**
	 * @name newCompletedUpdate
	 * @creation date: 31/08/2026
	 * @author: Jesus Piriz
	 * @description Builds (without DML) a Completed transition record for bulk update after callouts.
	 * @param externalFileId Id of the VL_ExternalFile__c record.
	 * @param remoteFileId Google Drive file identifier.
	 * @param remoteFolderId Google Drive folder identifier.
	 * @param remoteLinkUrl Shareable web view link.
	 * @return VL_ExternalFile__c update-ready record.
	 */
	public static VL_ExternalFile__c newCompletedUpdate(
		Id externalFileId,
		String remoteFileId,
		String remoteFolderId,
		String remoteLinkUrl
	) {
		return new VL_ExternalFile__c(
			Id = externalFileId,
			VL_Status__c = STATUS_COMPLETED,
			VL_RemoteFileId__c = remoteFileId,
			VL_RemoteFolderId__c = remoteFolderId,
			VL_RemoteLinkUrl__c = remoteLinkUrl,
			VL_UploadedDate__c = DateTime.now(),
			VL_UploadedByLookup__c = UserInfo.getUserId()
		);
	}

	/**
	 * @name newErrorUpdate
	 * @creation date: 31/08/2026
	 * @author: Jesus Piriz
	 * @description Builds (without DML) an Error transition record for bulk update after callouts.
	 * @param externalFileId Id of the VL_ExternalFile__c record.
	 * @param errorMessage Diagnostic message describing the failure.
	 * @return VL_ExternalFile__c update-ready record.
	 */
	public static VL_ExternalFile__c newErrorUpdate(Id externalFileId, String errorMessage) {
		return new VL_ExternalFile__c(Id = externalFileId, VL_Status__c = STATUS_ERROR, VL_LastErrorTxtArea__c = errorMessage);
	}

	/**
	 * @name newRetryUpdate
	 * @creation date: 31/08/2026
	 * @author: Jesus Piriz
	 * @description Builds (without DML) a retry-counter increment record for bulk update after callouts.
	 * @param externalFileId Id of the VL_ExternalFile__c record.
	 * @param currentRetryCount Retry count read from the batch query; null treated as zero.
	 * @return VL_ExternalFile__c update-ready record.
	 */
	public static VL_ExternalFile__c newRetryUpdate(Id externalFileId, Integer currentRetryCount) {
		Integer base = currentRetryCount == null ? 0 : currentRetryCount;
		return new VL_ExternalFile__c(Id = externalFileId, VL_RetryCountNumber__c = base + 1);
	}

	/**
	 * @name applyUpdates
	 * @creation date: 31/08/2026
	 * @author: Jesus Piriz
	 * @description Persists a batch of transition records in a single DML after all callouts complete.
	 * @param records Update-ready VL_ExternalFile__c records.
	 */
	public static void applyUpdates(List<VL_ExternalFile__c> records) {
		if (records == null || records.isEmpty()) {
			return;
		}
		Database.update(records, AccessLevel.USER_MODE);
	}

	// ── Private helpers ──────────────────────────────────────────────────────────

	private static VL_ExternalFile__c buildPending(VL_TransferRequest req) {
		return new VL_ExternalFile__c(
			VL_ParentRecordId__c = String.valueOf(req.parentRecordId),
			VL_ParentObjectApiName__c = req.parentObjectApiName,
			VL_ContentDocumentId__c = req.contentDocumentId,
			VL_ContentVersionId__c = req.contentVersionId,
			VL_LogicalKey__c = req.logicalKey,
			VL_Status__c = STATUS_PENDING,
			VL_RetryCountNumber__c = 0
		);
	}
}