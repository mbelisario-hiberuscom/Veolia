/**
 * @name VL_GoogleDriveUploadQueueable
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Async Queueable that processes a batch of document transfer requests.
 *              Applies idempotency check, orchestrates folder resolution and upload,
 *              manages retry policy for recoverable errors, and triggers cleanup on success.
 */
public with sharing class VL_GoogleDriveUploadQueueable implements Queueable, Database.AllowsCallouts {
	@TestVisible
	private static Boolean suppressRequeue = false;
	private List<VL_TransferRequest> requests;
	private Integer retryCount;

	/**
	 * @name VL_GoogleDriveUploadQueueable
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Constructs the queueable with a list of transfer requests.
	 * @param requests Transfer requests to process.
	 */
	public VL_GoogleDriveUploadQueueable(List<VL_TransferRequest> requests) {
		this.requests = requests;
		this.retryCount = 0;
	}

	/**
	 * @name VL_GoogleDriveUploadQueueable
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Constructs the queueable with retry state carried over from a previous run.
	 * @param requests Transfer requests to process.
	 * @param retryCount Current retry count inherited from the previous attempt.
	 */
	public VL_GoogleDriveUploadQueueable(List<VL_TransferRequest> requests, Integer retryCount) {
		this.requests = requests;
		this.retryCount = retryCount;
	}

	/**
	 * @name execute
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Executes one transfer cycle per request with idempotency, retry, and cleanup.
	 * @param ctx Queueable context provided by the platform.
	 */
	public void execute(QueueableContext ctx) {
		VL_GoogleDriveConfigDTO config;
		try {
			config = VL_GoogleDriveConfigSelector.getActive();
		} catch (VL_GoogleDriveException ex) {
			FWERR_ErrorHandler.insertError(ex);
			return;
		}

		// Re-check idempotency before doing any work
		Set<String> logicalKeys = new Set<String>();
		for (VL_TransferRequest req : requests) {
			logicalKeys.add(req.logicalKey);
		}
		Set<String> alreadyCompleted = VL_ExternalFileService.findCompletedKeys(logicalKeys);

		List<VL_TransferRequest> pending = new List<VL_TransferRequest>();
		for (VL_TransferRequest req : requests) {
			if (!alreadyCompleted.contains(req.logicalKey)) {
				pending.add(req);
			}
		}
		if (pending.isEmpty()) {
			return;
		}

		// Look up existing ExternalFile records for this batch
		Map<String, VL_ExternalFile__c> externalFileByKey = queryExternalFilesByKeys(logicalKeys);

		VL_GoogleDriveServiceOrchestrator orchestrator = new VL_GoogleDriveServiceOrchestrator();
		List<VL_TransferRequest> toRetry = new List<VL_TransferRequest>();
		List<Id> completedIds = new List<Id>();
		// All Drive callouts must run before any DML; otherwise Salesforce raises
		// "uncommitted work pending". Transitions are accumulated and persisted in one bulk DML.
		List<VL_ExternalFile__c> recordsToUpdate = new List<VL_ExternalFile__c>();

		for (VL_TransferRequest req : pending) {
			VL_ExternalFile__c externalFile = externalFileByKey.get(req.logicalKey);
			if (externalFile == null) {
				continue;
			}

			ContentVersion cv = loadContentVersion(req.contentVersionId);
			if (cv == null) {
				recordsToUpdate.add(
					VL_ExternalFileService.newErrorUpdate(externalFile.Id, 'ContentVersion not found: ' + req.contentVersionId)
				);
				continue;
			}

			// Max file size guard delegated to orchestrator
			try {
				String storedFolderId = externalFile.VL_RemoteFolderId__c;
				VL_GoogleDriveServiceOrchestrator.VL_OrchestratorResult result = orchestrator.transfer(
					req,
					config,
					storedFolderId,
					req.requestedDriveFolderId,
					cv
				);
				recordsToUpdate.add(
					VL_ExternalFileService.newCompletedUpdate(externalFile.Id, result.remoteFileId, result.remoteFolderId, result.webViewLink)
				);
				completedIds.add(externalFile.Id);
			} catch (VL_GoogleDriveException ex) {
				if (ex.isRecoverable() && retryCount < (config.maxRetries != null ? config.maxRetries : 3)) {
					recordsToUpdate.add(VL_ExternalFileService.newRetryUpdate(externalFile.Id, (Integer) externalFile.VL_RetryCountNumber__c));
					toRetry.add(req);
				} else {
					recordsToUpdate.add(VL_ExternalFileService.newErrorUpdate(externalFile.Id, ex.getMessage()));
					FWERR_ErrorHandler.insertError(ex);
				}
			} catch (Exception ex) {
				recordsToUpdate.add(VL_ExternalFileService.newErrorUpdate(externalFile.Id, ex.getMessage()));
				FWERR_ErrorHandler.insertError(ex);
			}
		}

		// Single bulk DML after all callouts have completed.
		VL_ExternalFileService.applyUpdates(recordsToUpdate);

		if (!completedIds.isEmpty()) {
			VL_FileCleanupService.cleanupIfSafe(completedIds);
		}

		if (!toRetry.isEmpty() && canRequeue()) {
			System.enqueueJob(new VL_GoogleDriveUploadQueueable(toRetry, retryCount + 1));
		}
	}

	// ── Private helpers ──────────────────────────────────────────────────────────

	private static Map<String, VL_ExternalFile__c> queryExternalFilesByKeys(Set<String> logicalKeys) {
		Map<String, VL_ExternalFile__c> result = new Map<String, VL_ExternalFile__c>();
		for (VL_ExternalFile__c rec : [
			SELECT Id, VL_LogicalKey__c, VL_RemoteFolderId__c, VL_RetryCountNumber__c
			FROM VL_ExternalFile__c
			WHERE VL_LogicalKey__c IN :logicalKeys
			WITH USER_MODE
		]) {
			result.put(rec.VL_LogicalKey__c, rec);
		}
		return result;
	}

	private static ContentVersion loadContentVersion(String versionId) {
		List<ContentVersion> versions = [
			SELECT Id, VersionData, ContentSize, FileType
			FROM ContentVersion
			WHERE Id = :versionId
			WITH USER_MODE
			LIMIT 1
		];
		return versions.isEmpty() ? null : versions[0];
	}

	private static Boolean canRequeue() {
		return !suppressRequeue && !System.isBatch() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs();
	}
}