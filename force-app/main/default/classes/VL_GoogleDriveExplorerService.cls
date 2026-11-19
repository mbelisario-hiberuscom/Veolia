/**
 * @name VL_GoogleDriveExplorerService
 * @version 1.0
 * @creation date: 01/09/2026
 * @author: Jesus Piriz
 * @description Read-only navigation of the live Google Drive folder tree for a Salesforce record.
 *              Resolves the record folder (root → object → record) without creating anything and
 *              lists the direct children (files and sub-folders) of any folder for the explorer LWC.
 */
public with sharing class VL_GoogleDriveExplorerService {
	private static final String FOLDER_MIME = 'application/vnd.google-apps.folder';
	private static final String LEAD_OBJECT_API_NAME = 'Lead';
	private static final String LIST_FIELDS = 'files(id,name,mimeType,size,modifiedTime,webViewLink)';
	@TestVisible
	private static Map<Id, String> convertedLeadNamesByIdForTest;

	/**
	 * @name resolveRecordFolder
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Resolves the live Drive folder for a record by searching root → object → record.
	 *              No folder is created; folderId is null when the record folder does not exist yet.
	 * @param recordId Salesforce Id of the parent record.
	 * @return VL_DriveFolderDTO resolved folder (folderId may be null); folderName is the record folder name.
	 */
	public static VL_DriveFolderDTO resolveRecordFolder(Id recordId) {
		VL_GoogleDriveConfigDTO config = VL_GoogleDriveConfigSelector.getActive();
		VL_GoogleDriveFolderService folderService = new VL_GoogleDriveFolderService(new VL_GoogleDriveHttpClient());

		VL_ResolvedRecord resolved = VL_SalesforceRecordResolver.resolve(new Set<Id>{ recordId }).get(recordId);
		String objectApiName = resolved != null ? resolved.objectApiName : recordId.getSObjectType().getDescribe().getName();
		String recordName = resolved != null ? resolved.recordName : '';
		String folderName = buildFolderName(config.folderNamingPattern, recordId, recordName);

		VL_DriveFolderDTO result = new VL_DriveFolderDTO();
		result.folderName = folderName;

		String objectFolderId = folderService.findFolder(objectApiName, config.rootFolderId, config.sharedDriveId);
		if (String.isBlank(objectFolderId)) {
			return result;
		}
		result.folderId = folderService.findFolder(folderName, objectFolderId, config.sharedDriveId);
		return result;
	}

	/**
	 * @name ensureRecordFolder
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Creates or reuses the complete Drive hierarchy for a Salesforce record: object folder,
	 *              record folder, and all active subfolders configured for the record's object.
	 * @param recordId Salesforce Id of the parent record.
	 * @return VL_DriveFolderDTO containing the created or existing record folder.
	 */
	public static VL_DriveFolderDTO ensureRecordFolder(Id recordId) {
		if (recordId == null) {
			return null;
		}

		VL_GoogleDriveConfigDTO config = VL_GoogleDriveConfigSelector.getActive();
		VL_ResolvedRecord resolved = VL_SalesforceRecordResolver.resolve(new Set<Id>{ recordId }).get(recordId);
		if (resolved == null || String.isBlank(resolved.objectApiName)) {
			throw new VL_GoogleDriveException(
				'Unable to resolve the Salesforce record for Google Drive folder creation.',
				VL_GoogleDriveException.ErrorCategory.TERMINAL_CONFIG
			);
		}
		String objectApiName = resolved.objectApiName;
		if (!config.isActive || config.enabledObjects == null || !config.enabledObjects.contains(objectApiName.toLowerCase())) {
			throw new VL_GoogleDriveException(
				'Google Drive integration is not enabled for ' + objectApiName + '.',
				VL_GoogleDriveException.ErrorCategory.TERMINAL_CONFIG
			);
		}

		VL_GoogleDriveFolderService folderService = new VL_GoogleDriveFolderService(new VL_GoogleDriveHttpClient());
		String objectFolderId = folderService.ensureObjectFolder(objectApiName, config.rootFolderId, config.sharedDriveId);
		String folderName = buildFolderName(config.folderNamingPattern, recordId, resolved.recordName);
		String recordFolderId = folderService.ensureRecordFolder(objectFolderId, folderName, null, config.sharedDriveId);
		folderService.ensureConfiguredSubfolders(objectApiName, recordFolderId, config.sharedDriveId);

		VL_DriveFolderDTO result = new VL_DriveFolderDTO();
		result.folderId = recordFolderId;
		result.folderName = folderName;
		return result;
	}

	/**
	 * @name listChildren
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Lists the direct children (files and sub-folders) of a Drive folder, folders first.
	 * @param folderId Drive Id of the folder to list.
	 * @return List<VL_DriveItemDTO> child entries; empty when the folder has no children.
	 */
	public static List<VL_DriveItemDTO> listChildren(String folderId) {
		VL_GoogleDriveConfigDTO config = VL_GoogleDriveConfigSelector.getActive();
		String query = '\'' + folderId.replace('\'', '\\\'') + '\' in parents and trashed=false';
		String path =
			'/drive/v3/files?q=' +
			EncodingUtil.urlEncode(query, 'UTF-8') +
			'&supportsAllDrives=true&includeItemsFromAllDrives=true&orderBy=folder,name&pageSize=1000&fields=' +
			EncodingUtil.urlEncode(LIST_FIELDS, 'UTF-8');
		if (String.isNotBlank(config.sharedDriveId)) {
			path += '&driveId=' + config.sharedDriveId + '&corpora=drive';
		}

		VL_GoogleDriveResponse resp = new VL_GoogleDriveHttpClient().sendJson('GET', path, null);
		if (!resp.success) {
			throw new VL_GoogleDriveException(
				'Drive folder listing failed: ' + resp.httpStatus + ' ' + resp.bodyJson,
				resp.category,
				resp.httpStatus
			);
		}
		return parseItems(resp.bodyJson);
	}

	/**
	 * @name listChildrenForRecord
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Lists a record folder and, for an Opportunity root, adds one virtual read-only folder for each converted Lead.
	 *              Virtual folders point to the existing Lead folder in Drive and never copy or move content.
	 * @param folderId Drive Id of the folder to list.
	 * @param recordId Salesforce record Id represented by the folder.
	 * @return List<VL_DriveItemDTO> real Drive entries plus linked Lead folders when applicable.
	 */
	public static List<VL_DriveItemDTO> listChildrenForRecord(String folderId, Id recordId) {
		List<VL_DriveItemDTO> items = listChildren(folderId);
		VL_DriveFolderDTO recordFolder = recordId == null ? null : resolveRecordFolder(recordId);
		items = mergeUnsyncedItems(items, recordId, folderId, recordFolder?.folderId);
		if (recordId == null || recordId.getSObjectType().getDescribe().getName() != 'Opportunity') {
			return items;
		}

		if (String.isBlank(recordFolder?.folderId) || recordFolder.folderId != folderId) {
			return items;
		}

		List<VL_DriveItemDTO> linkedLeadFolders = resolveConvertedLeadFolders(recordId);
		if (linkedLeadFolders.isEmpty()) {
			return items;
		}
		return mergeLinkedFolders(items, linkedLeadFolders);
	}

	// ── Private helpers ─────────────────────────────────────────────────────────

	private static String buildFolderName(String pattern, Id recordId, String recordName) {
		String safeName = recordName != null ? recordName : '';
		if (String.isBlank(pattern)) {
			return String.valueOf(recordId) + '-' + safeName;
		}
		return pattern.replace('{RecordId}', String.valueOf(recordId)).replace('{RecordName}', safeName);
	}

	private static List<VL_DriveItemDTO> parseItems(String bodyJson) {
		List<VL_DriveItemDTO> items = new List<VL_DriveItemDTO>();
		if (String.isBlank(bodyJson)) {
			return items;
		}
		Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(bodyJson);
		List<Object> files = (List<Object>) parsed.get('files');
		if (files == null) {
			return items;
		}
		for (Object raw : files) {
			Map<String, Object> file = (Map<String, Object>) raw;
			VL_DriveItemDTO dto = new VL_DriveItemDTO();
			dto.id = (String) file.get('id');
			dto.name = (String) file.get('name');
			dto.mimeType = (String) file.get('mimeType');
			dto.isFolder = FOLDER_MIME.equals(dto.mimeType);
			dto.isLinkedFolder = false;
			dto.isReadOnly = false;
			dto.modifiedTime = (String) file.get('modifiedTime');
			dto.webViewLink = (String) file.get('webViewLink');
			Object sizeValue = file.get('size');
			if (sizeValue != null) {
				dto.sizeBytes = Long.valueOf(String.valueOf(sizeValue));
			}
			items.add(dto);
		}
		return items;
	}

	private static List<VL_DriveItemDTO> resolveConvertedLeadFolders(Id opportunityId) {
		Map<Id, String> leadNamesById = getConvertedLeadNames(opportunityId);
		List<VL_DriveItemDTO> linkedFolders = new List<VL_DriveItemDTO>();
		if (leadNamesById.isEmpty()) {
			return linkedFolders;
		}

		VL_GoogleDriveConfigDTO config = VL_GoogleDriveConfigSelector.getActive();
		VL_GoogleDriveFolderService folderService = new VL_GoogleDriveFolderService(new VL_GoogleDriveHttpClient());
		String leadObjectFolderId = folderService.findFolder(LEAD_OBJECT_API_NAME, config.rootFolderId, config.sharedDriveId);
		if (String.isBlank(leadObjectFolderId)) {
			return linkedFolders;
		}

		for (Id leadId : leadNamesById.keySet()) {
			String leadFolderName = buildFolderName(config.folderNamingPattern, leadId, leadNamesById.get(leadId));
			String leadFolderId = folderService.findFolder(leadFolderName, leadObjectFolderId, config.sharedDriveId);
			if (String.isBlank(leadFolderId)) {
				continue;
			}
			VL_DriveItemDTO linkedFolder = new VL_DriveItemDTO();
			linkedFolder.id = leadFolderId;
			linkedFolder.name = String.format(
				System.Label.VL_GoogleDriveFilesOriginalLeadFolder,
				new List<String>{ leadNamesById.get(leadId) }
			);
			linkedFolder.isFolder = true;
			linkedFolder.isLinkedFolder = true;
			linkedFolder.isReadOnly = true;
			linkedFolders.add(linkedFolder);
		}
		return linkedFolders;
	}

	private static Map<Id, String> getConvertedLeadNames(Id opportunityId) {
		if (Test.isRunningTest() && convertedLeadNamesByIdForTest != null) {
			return convertedLeadNamesByIdForTest;
		}

		Map<Id, String> leadNamesById = new Map<Id, String>();
		for (Lead lead : [
			SELECT Id, Name
			FROM Lead
			WHERE ConvertedOpportunityId = :opportunityId AND IsConverted = TRUE
			WITH USER_MODE
			ORDER BY Name, Id
		]) {
			leadNamesById.put(lead.Id, lead.Name);
		}
		return leadNamesById;
	}

	private static List<VL_DriveItemDTO> mergeLinkedFolders(List<VL_DriveItemDTO> items, List<VL_DriveItemDTO> linkedFolders) {
		Set<String> existingFolderIds = new Set<String>();
		List<VL_DriveItemDTO> folders = new List<VL_DriveItemDTO>();
		List<VL_DriveItemDTO> files = new List<VL_DriveItemDTO>();
		for (VL_DriveItemDTO item : items) {
			if (item.isFolder) {
				existingFolderIds.add(item.id);
				folders.add(item);
			} else {
				files.add(item);
			}
		}
		for (VL_DriveItemDTO linkedFolder : linkedFolders) {
			if (!existingFolderIds.contains(linkedFolder.id)) {
				folders.add(linkedFolder);
			}
		}
		folders.addAll(files);
		return folders;
	}

	private static List<VL_DriveItemDTO> mergeUnsyncedItems(
		List<VL_DriveItemDTO> items,
		Id recordId,
		String folderId,
		String recordFolderId
	) {
		List<VL_DriveItemDTO> unsyncedItems = VL_ExternalFileService.findUnsyncedDriveItems(recordId, folderId, recordFolderId);
		if (unsyncedItems.isEmpty()) {
			return items;
		}
		List<VL_DriveItemDTO> folders = new List<VL_DriveItemDTO>();
		List<VL_DriveItemDTO> files = new List<VL_DriveItemDTO>();
		for (VL_DriveItemDTO item : items) {
			if (item.isFolder) {
				folders.add(item);
			} else {
				files.add(item);
			}
		}
		files.addAll(unsyncedItems);
		folders.addAll(files);
		return folders;
	}
}