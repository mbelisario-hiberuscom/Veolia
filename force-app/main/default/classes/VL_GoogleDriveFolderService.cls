/**
 * @name VL_GoogleDriveFolderService
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Manages the Google Drive folder hierarchy (root → object → record → configured subfolders).
 *              Reuses existing folders by stored identifier; searches then creates only when absent.
 */
public with sharing class VL_GoogleDriveFolderService {
	private static final String FOLDER_MIME = 'application/vnd.google-apps.folder';

	private VL_GoogleDriveHttpClient httpClient;

	/**
	 * @name VL_GoogleDriveFolderService
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Constructor accepting the HTTP client dependency.
	 * @param httpClient Configured HTTP client for Drive API calls.
	 */
	public VL_GoogleDriveFolderService(VL_GoogleDriveHttpClient httpClient) {
		this.httpClient = httpClient;
	}

	/**
	 * @name ensureObjectFolder
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Returns or creates the object-level folder under the root.
	 * @param objectApiName Salesforce object API name used as the folder name.
	 * @param rootFolderId Drive Id of the root folder.
	 * @param sharedDriveId Drive Id of the Shared Drive; null for personal drive.
	 * @return String Google Drive folder Id.
	 */
	public String ensureObjectFolder(String objectApiName, String rootFolderId, String sharedDriveId) {
		return ensureFolder(objectApiName, rootFolderId, sharedDriveId);
	}

	/**
	 * @name ensureRecordFolder
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Returns the stored record folder or creates a new one under the object folder.
	 * @param objectFolderId Drive Id of the parent object folder.
	 * @param folderName Desired folder name derived from the naming pattern.
	 * @param storedFolderId Previously stored folder Id; when non-blank the folder is reused without search.
	 * @param sharedDriveId Drive Id of the Shared Drive; null for personal drive.
	 * @return String Google Drive folder Id.
	 */
	public String ensureRecordFolder(String objectFolderId, String folderName, String storedFolderId, String sharedDriveId) {
		if (String.isNotBlank(storedFolderId)) {
			return storedFolderId;
		}
		return ensureFolder(folderName, objectFolderId, sharedDriveId);
	}

	/**
	 * @name ensureConfiguredSubfolders
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Searches or creates the configured subfolders below a record folder. Existing folders are reused
	 *              and new configuration entries are picked up on a later transfer without duplicating folders.
	 * @param objectApiName Salesforce object API name that owns the record.
	 * @param recordFolderId Drive Id of the parent record folder.
	 * @param sharedDriveId Drive Id of the Shared Drive; null for personal drive.
	 * @return List<String> Drive Ids of the configured subfolders.
	 */
	public List<String> ensureConfiguredSubfolders(String objectApiName, String recordFolderId, String sharedDriveId) {
		List<String> folderIds = new List<String>();
		for (VL_GoogleDriveSubfolderConfigDTO folderConfig : VL_GoogleDriveSubfolderConfigSelector.getForObject(objectApiName)) {
			if (String.isBlank(folderConfig.folderName)) {
				continue;
			}
			folderIds.add(ensureFolder(folderConfig.folderName, recordFolderId, sharedDriveId));
		}
		return folderIds;
	}

	/**
	 * @name findFolder
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Read-only search for a folder by name under a parent. Returns null when absent,
	 *              never creating anything (used by the file explorer to resolve without side effects).
	 * @param name Folder name to search for.
	 * @param parentId Drive Id of the parent folder.
	 * @param sharedDriveId Drive Id of the Shared Drive; null for personal drive.
	 * @return String Google Drive folder Id, or null when not found.
	 */
	public String findFolder(String name, String parentId, String sharedDriveId) {
		return searchFolder(name, parentId, sharedDriveId);
	}

	// ── Private helpers ─────────────────────────────────────────────────────────

	private String ensureFolder(String name, String parentId, String sharedDriveId) {
		String existingId = searchFolder(name, parentId, sharedDriveId);
		if (String.isNotBlank(existingId)) {
			return existingId;
		}
		return createFolder(name, parentId, sharedDriveId);
	}

	private String searchFolder(String name, String parentId, String sharedDriveId) {
		String escapedName = name.replace('\'', '\\\'');
		String query =
			'name=\'' +
			escapedName +
			'\' and \'' +
			parentId +
			'\' in parents and mimeType=\'' +
			FOLDER_MIME +
			'\' and trashed=false';
		String path =
			'/drive/v3/files?q=' +
			EncodingUtil.urlEncode(query, 'UTF-8') +
			'&supportsAllDrives=true&includeItemsFromAllDrives=true&fields=files(id,name)';
		if (String.isNotBlank(sharedDriveId)) {
			path += '&driveId=' + sharedDriveId + '&corpora=drive';
		}
		VL_GoogleDriveResponse resp = httpClient.sendJson('GET', path, null);
		if (!resp.success) {
			throw new VL_GoogleDriveException(
				'Drive folder search failed: ' + resp.httpStatus + ' ' + resp.bodyJson,
				resp.category,
				resp.httpStatus
			);
		}
		return extractFirstFileId(resp.bodyJson);
	}

	private String createFolder(String name, String parentId, String sharedDriveId) {
		Map<String, Object> metadata = new Map<String, Object>{
			'name' => name,
			'mimeType' => FOLDER_MIME,
			'parents' => new List<String>{ parentId }
		};
		String path = '/drive/v3/files?supportsAllDrives=true';
		VL_GoogleDriveResponse resp = httpClient.sendJson('POST', path, JSON.serialize(metadata));
		if (!resp.success) {
			throw new VL_GoogleDriveException(
				'Drive folder creation failed: ' + resp.httpStatus + ' ' + resp.bodyJson,
				resp.category,
				resp.httpStatus
			);
		}
		return resp.remoteId;
	}

	/**
	 * @name extractFirstFileId
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Extracts the Id of the first file from a Drive files.list JSON response.
	 * @param json JSON response returned by the Drive files.list endpoint.
	 * @return String first file Id, or null when no file Id is present.
	 */
	private static String extractFirstFileId(String json) {
		if (String.isBlank(json) || !json.contains('"files"')) {
			return null;
		}
		Integer filesIdx = json.indexOf('"files"');
		Integer arrStart = json.indexOf('[', filesIdx);
		Integer arrEnd = json.indexOf(']', arrStart);
		if (arrStart == -1 || arrEnd == -1 || arrEnd == arrStart + 1) {
			return null;
		}
		String filesContent = json.substring(arrStart + 1, arrEnd);
		Integer idIdx = filesContent.indexOf('"id"');
		if (idIdx == -1) {
			return null;
		}
		Integer colonIdx = filesContent.indexOf(':', idIdx);
		Integer startQuote = filesContent.indexOf('"', colonIdx + 1);
		Integer endQuote = filesContent.indexOf('"', startQuote + 1);
		if (startQuote == -1 || endQuote == -1) {
			return null;
		}
		return filesContent.substring(startQuote + 1, endQuote);
	}
}