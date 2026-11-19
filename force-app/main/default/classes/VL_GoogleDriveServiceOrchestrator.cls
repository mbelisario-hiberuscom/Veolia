/**
 * @name VL_GoogleDriveServiceOrchestrator
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Orchestrates the end-to-end Google Drive transfer: resolves folder hierarchy,
 *              uploads the file binary, and returns a classified response.
 *              Short-circuits via idempotency check before calling any external service.
 */
public with sharing class VL_GoogleDriveServiceOrchestrator {
	private static final Decimal DEFAULT_MAX_FILE_SIZE_MB = 25;
	private static final Integer BYTES_PER_DECIMAL_MB = 1000000;
	private static final Integer SALESFORCE_MAX_CALLOUT_BYTES = 25000000;
	private VL_GoogleDriveFolderService folderService;
	private VL_GoogleDriveFileService fileService;

	/**
	 * @name VL_GoogleDriveServiceOrchestrator
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Constructs the orchestrator with default HTTP-backed service instances.
	 */
	public VL_GoogleDriveServiceOrchestrator() {
		VL_GoogleDriveHttpClient httpClient = new VL_GoogleDriveHttpClient();
		this.folderService = new VL_GoogleDriveFolderService(httpClient);
		this.fileService = new VL_GoogleDriveFileService(httpClient);
	}

	/**
	 * @name VL_GoogleDriveServiceOrchestrator
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Test-injection constructor for mocked service dependencies.
	 * @param folderService Folder service instance.
	 * @param fileService File upload service instance.
	 */
	@TestVisible
	private VL_GoogleDriveServiceOrchestrator(VL_GoogleDriveFolderService folderService, VL_GoogleDriveFileService fileService) {
		this.folderService = folderService;
		this.fileService = fileService;
	}

	/**
	 * @name transfer
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Resolves the object, record, and configured subfolders, then uploads the file binary to the requested valid destination.
	 *              Returns a classified response. Throws VL_GoogleDriveException on failure.
	 * @param req Transfer request containing parent record, document, and version details.
	 * @param config Active configuration from VL_GoogleDriveConfiguration__mdt.
	 * @param storedFolderId Previously resolved record folder Id; blank forces folder resolution.
	 * @param contentVersion Loaded ContentVersion with VersionData and ContentSize.
	 * @return VL_GoogleDriveResponse with remoteId, webViewLink, and the resolved record folder Id.
	 */
	public VL_OrchestratorResult transfer(
		VL_TransferRequest req,
		VL_GoogleDriveConfigDTO config,
		String storedFolderId,
		ContentVersion contentVersion
	) {
		return transfer(req, config, storedFolderId, null, contentVersion);
	}

	/**
	 * @name transfer
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Transfers a file to the record folder or one of its configured subfolders according to the selected folder.
	 *              A non-blank selected folder must belong to the resolved record hierarchy.
	 * @param req Transfer request containing parent record, document, and version details.
	 * @param config Active configuration from VL_GoogleDriveConfiguration__mdt.
	 * @param storedFolderId Previously resolved record folder Id; blank forces folder resolution.
	 * @param requestedDriveFolderId Folder Id selected in the LWC, or null for the record folder destination.
	 * @param contentVersion Loaded ContentVersion with VersionData and ContentSize.
	 * @return Result containing the uploaded file Id, record folder Id, and web link.
	 */
	public VL_OrchestratorResult transfer(
		VL_TransferRequest req,
		VL_GoogleDriveConfigDTO config,
		String storedFolderId,
		String requestedDriveFolderId,
		ContentVersion contentVersion
	) {
		// Max file size guard
		Integer maxBytes = calculateMaxUploadBytes(config.maxFileSizeMb);
		Integer contentSize = contentVersion.ContentSize;
		if (contentSize == null && contentVersion.VersionData != null) {
			contentSize = contentVersion.VersionData.size();
		}
		if (contentSize != null && contentSize > maxBytes) {
			throw new VL_GoogleDriveException(
				'File exceeds maximum upload size of ' +
					maxBytes +
					' bytes. Salesforce callout limit is ' +
					SALESFORCE_MAX_CALLOUT_BYTES +
					' bytes.',
				VL_GoogleDriveException.ErrorCategory.TERMINAL_VALIDATION
			);
		}

		String objectFolderId = folderService.ensureObjectFolder(req.parentObjectApiName, config.rootFolderId, config.sharedDriveId);
		String folderName = buildFolderName(config.folderNamingPattern, req);
		String recordFolderId = folderService.ensureRecordFolder(objectFolderId, folderName, storedFolderId, config.sharedDriveId);
		List<String> configuredSubfolderIds = folderService.ensureConfiguredSubfolders(
			req.parentObjectApiName,
			recordFolderId,
			config.sharedDriveId
		);
		String destinationFolderId = resolveDestinationFolderId(requestedDriveFolderId, recordFolderId, configuredSubfolderIds);

		VL_GoogleDriveResponse uploadResp = fileService.upload(
			contentVersion.VersionData,
			req.contentTitle,
			req.mimeType,
			destinationFolderId
		);
		if (!uploadResp.success) {
			throw new VL_GoogleDriveException(
				'File upload failed: ' + uploadResp.httpStatus + ' ' + uploadResp.bodyJson,
				uploadResp.category,
				uploadResp.httpStatus
			);
		}
		return new VL_OrchestratorResult(uploadResp.remoteId, recordFolderId, uploadResp.webViewLink);
	}

	// ── Private helpers ──────────────────────────────────────────────────────────

	/**
	 * @name calculateMaxUploadBytes
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Converts the configured decimal MB limit to bytes and caps it at Salesforce's HTTP callout limit.
	 * @param configuredMaxMb Configured maximum file size in decimal MB, or null for the default.
	 * @return Effective maximum upload size in bytes.
	 */
	@TestVisible
	public static Integer calculateMaxUploadBytes(Decimal configuredMaxMb) {
		Decimal effectiveMaxMb = configuredMaxMb != null ? configuredMaxMb : DEFAULT_MAX_FILE_SIZE_MB;
		if (effectiveMaxMb >= DEFAULT_MAX_FILE_SIZE_MB) {
			return SALESFORCE_MAX_CALLOUT_BYTES;
		}
		return (Integer) (effectiveMaxMb * BYTES_PER_DECIMAL_MB);
	}

	private static String buildFolderName(String pattern, VL_TransferRequest req) {
		if (String.isBlank(pattern)) {
			return String.valueOf(req.parentRecordId) + '-' + req.parentRecordName;
		}
		return pattern
			.replace('{RecordId}', String.valueOf(req.parentRecordId))
			.replace('{RecordName}', req.parentRecordName != null ? req.parentRecordName : '');
	}

	private static String resolveDestinationFolderId(String requestedFolderId, String recordFolderId, List<String> configuredSubfolderIds) {
		if (String.isBlank(requestedFolderId)) {
			return recordFolderId;
		}
		if (requestedFolderId == recordFolderId) {
			return recordFolderId;
		}
		if (configuredSubfolderIds != null && configuredSubfolderIds.contains(requestedFolderId)) {
			return requestedFolderId;
		}
		throw new VL_GoogleDriveException(
			'Invalid Google Drive destination folder for the Salesforce record.',
			VL_GoogleDriveException.ErrorCategory.TERMINAL_VALIDATION
		);
	}

	/**
	 * @name VL_OrchestratorResult
	 * @version 1.0
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Carries the Drive identifiers produced by a successful transfer.
	 */
	public class VL_OrchestratorResult {
		/** Google Drive file identifier. */
		public String remoteFileId;
		/** Google Drive record folder identifier. */
		public String remoteFolderId;
		/** Shareable web view link for the uploaded file. */
		public String webViewLink;

		/**
		 * @name VL_OrchestratorResult
		 * @creation date: 27/08/2026
		 * @author: Jesus Piriz
		 * @description Constructs the result from the upload response.
		 * @param remoteFileId Drive file identifier.
		 * @param remoteFolderId Drive folder identifier.
		 * @param webViewLink Shareable link.
		 */
		public VL_OrchestratorResult(String remoteFileId, String remoteFolderId, String webViewLink) {
			this.remoteFileId = remoteFileId;
			this.remoteFolderId = remoteFolderId;
			this.webViewLink = webViewLink;
		}
	}
}