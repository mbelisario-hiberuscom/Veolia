/**
 * @name VL_ContentDocumentLinkTriggerHelper
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Bulk-safe helper for the ContentDocumentLink after-insert trigger.
 *              Resolves parent objects dynamically, filters to enabled objects, and enqueues
 *              a single VL_GoogleDriveUploadQueueable for the entire trigger batch.
 */
public inherited sharing class VL_ContentDocumentLinkTriggerHelper {
	private static final Set<String> SUPPORTED_OBJECTS = new Set<String>{ 'lead', 'account', 'opportunity', 'quote' };

	/**
	 * @name handleAfterInsert
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Processes a list of newly inserted ContentDocumentLink records.
	 *              Short-circuits on inactive config or no enabled links.
	 *              Enqueues a single async job for all qualifying transfer requests.
	 * @param links List of ContentDocumentLink records from Trigger.new.
	 */
	public static void handleAfterInsert(List<ContentDocumentLink> links) {
		if (links == null || links.isEmpty()) {
			return;
		}
		Map<Id, String> objectTypeByParentId = new Map<Id, String>();
		for (ContentDocumentLink link : links) {
			if (link.LinkedEntityId == null) {
				continue;
			}
			Schema.SObjectType sType = link.LinkedEntityId.getSObjectType();
			if (sType == null) {
				continue;
			}
			String typeName = sType.getDescribe().getName().toLowerCase();
			if (SUPPORTED_OBJECTS.contains(typeName)) {
				objectTypeByParentId.put(link.LinkedEntityId, typeName);
			}
		}
		if (objectTypeByParentId.isEmpty()) {
			return;
		}

		VL_GoogleDriveConfigDTO config;
		try {
			config = VL_GoogleDriveConfigSelector.getActive();
		} catch (VL_GoogleDriveException ex) {
			return;
		}
		if (!config.isActive) {
			return;
		}

		Set<String> enabledObjects = config.enabledObjects == null ? new Set<String>() : new Set<String>(config.enabledObjects);
		Set<Id> parentIds = new Set<Id>();
		for (Id parentId : objectTypeByParentId.keySet()) {
			if (enabledObjects.contains(objectTypeByParentId.get(parentId))) {
				parentIds.add(parentId);
			}
		}
		if (parentIds.isEmpty()) {
			return;
		}

		// Collect document Ids
		Set<Id> docIds = new Set<Id>();
		for (ContentDocumentLink link : links) {
			if (parentIds.contains(link.LinkedEntityId)) {
				docIds.add(link.ContentDocumentId);
			}
		}

		// Single SOQL: fetch latest ContentVersion for each document
		Map<Id, ContentVersion> versionByDocId = new Map<Id, ContentVersion>();
		for (ContentVersion cv : [
			SELECT Id, ContentDocumentId, Title, FileType, ContentSize, VL_GoogleDriveFolder_fileupload__c
			FROM ContentVersion
			WHERE ContentDocumentId IN :docIds AND IsLatest = TRUE
			WITH USER_MODE
		]) {
			versionByDocId.put(cv.ContentDocumentId, cv);
		}

		Integer maxBytes = VL_GoogleDriveServiceOrchestrator.calculateMaxUploadBytes(config.maxFileSizeMb);
		Boolean hasOversizedFile = false;
		for (ContentDocumentLink link : links) {
			if (!parentIds.contains(link.LinkedEntityId)) {
				continue;
			}
			ContentVersion cv = versionByDocId.get(link.ContentDocumentId);
			if (cv != null && cv.ContentSize != null && cv.ContentSize > maxBytes) {
				link.addError(System.Label.VL_GoogleDriveFilesFileTooLarge.replace('{0}', String.valueOf(Decimal.valueOf(maxBytes) / 1000000)));
				hasOversizedFile = true;
			}
		}
		if (hasOversizedFile) {
			return;
		}

		// Resolve parent record names in bulk
		Map<Id, VL_ResolvedRecord> resolvedRecords = new Map<Id, VL_ResolvedRecord>();
		try {
			resolvedRecords = VL_SalesforceRecordResolver.resolve(parentIds);
		} catch (Exception ex) {
			FWERR_ErrorHandler.insertError(ex);
			return;
		}

		// Build transfer requests
		List<VL_TransferRequest> transferRequests = new List<VL_TransferRequest>();
		for (ContentDocumentLink link : links) {
			if (!parentIds.contains(link.LinkedEntityId)) {
				continue;
			}
			ContentVersion cv = versionByDocId.get(link.ContentDocumentId);
			if (cv == null) {
				continue;
			}
			VL_ResolvedRecord resolved = resolvedRecords.get(link.LinkedEntityId);
			if (resolved == null) {
				continue;
			}
			String mimeType = String.isNotBlank(cv.FileType) ? 'application/' + cv.FileType.toLowerCase() : 'application/octet-stream';
			transferRequests.add(
				new VL_TransferRequest(
					link.LinkedEntityId,
					resolved.objectApiName,
					resolved.recordName,
					String.valueOf(link.ContentDocumentId),
					String.valueOf(cv.Id),
					cv.Title,
					mimeType,
					cv.VL_GoogleDriveFolder_fileupload__c
				)
			);
		}
		if (transferRequests.isEmpty()) {
			return;
		}

		// Create pending traceability records before enqueueing
		VL_ExternalFileService.createPendingRecords(transferRequests);

		if (canEnqueue()) {
			System.enqueueJob(new VL_GoogleDriveUploadQueueable(transferRequests));
		}
	}

	private static Boolean canEnqueue() {
		return !System.isBatch() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs();
	}
}