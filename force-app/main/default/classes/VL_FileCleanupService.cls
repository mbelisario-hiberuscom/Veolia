/**
 * @name VL_FileCleanupService
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Deletes Salesforce ContentDocument binaries only after a fully successful transfer
 *              and only when the document has one real record link. Salesforce's implicit User
 *              link is excluded from this check. Documents linked to multiple records are marked
 *              Manual Review; deletion is never attempted for them.
 */
public with sharing class VL_FileCleanupService {
	/**
	 * @name cleanupIfSafe
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description For each Completed VL_ExternalFile__c, deletes the Salesforce binary when
	 *              the document is linked to exactly one record and autoCleanup is enabled.
	 *              Sets Manual Review when linked to multiple records; transitions to Error on
	 *              deletion failure without rolling back the upload.
	 * @param externalFileIds List of VL_ExternalFile__c Ids to evaluate for cleanup.
	 */
	public static void cleanupIfSafe(List<Id> externalFileIds) {
		if (externalFileIds == null || externalFileIds.isEmpty()) {
			return;
		}
		VL_GoogleDriveConfigDTO config;
		try {
			config = VL_GoogleDriveConfigSelector.getActive();
		} catch (VL_GoogleDriveException ex) {
			return;
		}
		if (!config.autoCleanup) {
			return;
		}

		List<VL_ExternalFile__c> records = [
			SELECT Id, VL_ContentDocumentId__c
			FROM VL_ExternalFile__c
			WHERE Id IN :externalFileIds AND VL_Status__c = 'Completed'
			WITH USER_MODE
		];
		if (records.isEmpty()) {
			return;
		}

		Set<String> docIds = new Set<String>();
		for (VL_ExternalFile__c rec : records) {
			docIds.add(rec.VL_ContentDocumentId__c);
		}
		Map<String, Integer> linkCountByDocId = countRecordLinks(docIds);

		List<Id> docsToDelete = new List<Id>();
		for (VL_ExternalFile__c rec : records) {
			Integer linkCount = linkCountByDocId.containsKey(rec.VL_ContentDocumentId__c)
				? linkCountByDocId.get(rec.VL_ContentDocumentId__c)
				: 0;
			if (linkCount == 1) {
				docsToDelete.add((Id) rec.VL_ContentDocumentId__c);
			} else {
				VL_ExternalFileService.markManualReview(rec.Id, 'Document linked to ' + linkCount + ' records; manual deletion required.');
			}
		}

		if (!docsToDelete.isEmpty()) {
			attemptDelete(docsToDelete, records);
		}
	}

	// ── Private helpers ──────────────────────────────────────────────────────────

	private static Map<String, Integer> countRecordLinks(Set<String> docIds) {
		Map<String, Integer> counts = new Map<String, Integer>();
		for (ContentDocumentLink link : [
			SELECT ContentDocumentId, LinkedEntityId, ShareType
			FROM ContentDocumentLink
			WHERE ContentDocumentId IN :docIds
			WITH USER_MODE
		]) {
			if (isImplicitUserLink(link)) {
				continue;
			}
			String documentId = String.valueOf(link.ContentDocumentId);
			counts.put(documentId, counts.containsKey(documentId) ? counts.get(documentId) + 1 : 1);
		}
		return counts;
	}

	private static Boolean isImplicitUserLink(ContentDocumentLink link) {
		return link.LinkedEntityId != null && link.LinkedEntityId.getSObjectType() == User.sObjectType && link.ShareType == 'I';
	}

	private static void attemptDelete(List<Id> docIds, List<VL_ExternalFile__c> sourceRecords) {
		List<ContentDocument> toDelete = new List<ContentDocument>();
		for (Id docId : docIds) {
			toDelete.add(new ContentDocument(Id = docId));
		}
		try {
			Database.delete(toDelete, AccessLevel.USER_MODE);
			// Mark source-deleted flag on matching ExternalFile records
			Map<Id, Id> docToExternalFile = new Map<Id, Id>();
			for (VL_ExternalFile__c rec : sourceRecords) {
				docToExternalFile.put((Id) rec.VL_ContentDocumentId__c, rec.Id);
			}
			List<VL_ExternalFile__c> toUpdate = new List<VL_ExternalFile__c>();
			for (Id docId : docIds) {
				if (docToExternalFile.containsKey(docId)) {
					toUpdate.add(new VL_ExternalFile__c(Id = docToExternalFile.get(docId), VL_IsSourceDeleted__c = true));
				}
			}
			if (!toUpdate.isEmpty()) {
				Database.update(toUpdate, AccessLevel.USER_MODE);
			}
		} catch (DmlException ex) {
			FWERR_ErrorHandler.insertError(ex);
			// Transition to Error without rolling back the upload
			Map<Id, Id> docToExternalFile = new Map<Id, Id>();
			for (VL_ExternalFile__c rec : sourceRecords) {
				docToExternalFile.put((Id) rec.VL_ContentDocumentId__c, rec.Id);
			}
			for (Id docId : docIds) {
				if (docToExternalFile.containsKey(docId)) {
					VL_ExternalFileService.markError(docToExternalFile.get(docId), 'Cleanup DML failed: ' + ex.getMessage());
				}
			}
		}
	}
}