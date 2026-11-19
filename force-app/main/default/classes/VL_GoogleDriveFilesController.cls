/**
 * @name VL_GoogleDriveFilesController
 * @version 2.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Apex controller for the vl_GoogleDriveFiles explorer LWC. Exposes live Google Drive
 *              navigation: resolves a record's Drive folder and lists a folder's children. Both
 *              methods perform callouts, so they are non-cacheable and invoked imperatively.
 */
public with sharing class VL_GoogleDriveFilesController {
	/**
	 * @name getMaxFileSizeMb
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Returns the active Custom Metadata file-size limit for administrative or server-side consumers.
	 * @return Maximum file size in decimal megabytes.
	 */
	@AuraEnabled(cacheable=true)
	public static Decimal getMaxFileSizeMb() {
		try {
			return VL_GoogleDriveConfigSelector.getActive().maxFileSizeMb;
		} catch (Exception ex) {
			FWERR_ErrorHandler.insertError(ex);
			throw new AuraHandledException(ex.getMessage());
		}
	}

	/**
	 * @name getRootFolder
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Resolves the live Google Drive folder for the given record (root → object → record).
	 * @param recordId Salesforce Id of the parent record.
	 * @return VL_DriveFolderDTO resolved folder; folderId is null when the record folder does not exist.
	 */
	@AuraEnabled
	public static VL_DriveFolderDTO getRootFolder(Id recordId) {
		if (recordId == null) {
			return null;
		}
		try {
			return VL_GoogleDriveExplorerService.resolveRecordFolder(recordId);
		} catch (Exception ex) {
			FWERR_ErrorHandler.insertError(ex);
			throw new AuraHandledException(ex.getMessage());
		}
	}

	/**
	 * @name ensureRecordFolder
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Creates or reuses the Google Drive object, record, and configured subfolders for a Salesforce record.
	 * @param recordId Salesforce Id of the parent record.
	 * @return VL_DriveFolderDTO containing the created or existing record folder.
	 */
	@AuraEnabled
	public static VL_DriveFolderDTO ensureRecordFolder(Id recordId) {
		if (recordId == null) {
			return null;
		}
		try {
			return VL_GoogleDriveExplorerService.ensureRecordFolder(recordId);
		} catch (Exception ex) {
			FWERR_ErrorHandler.insertError(ex);
			throw new AuraHandledException(ex.getMessage());
		}
	}

	/**
	 * @name listFolder
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Compatibility wrapper for Apex callers that only need the direct Drive listing.
	 * @param folderId Drive Id of the folder to list.
	 * @return List<VL_DriveItemDTO> child entries, folders first.
	 */
	public static List<VL_DriveItemDTO> listFolder(String folderId) {
		return listFolder(folderId, null);
	}

	/**
	 * @name listFolder
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Lists a folder and injects converted Lead folders only when folderId is the resolved Opportunity root.
	 * @param folderId Drive Id of the folder to list.
	 * @param recordId Salesforce record Id represented by the folder.
	 * @return List<VL_DriveItemDTO> child entries, folders first.
	 */
	@AuraEnabled
	public static List<VL_DriveItemDTO> listFolder(String folderId, Id recordId) {
		if (String.isBlank(folderId)) {
			return new List<VL_DriveItemDTO>();
		}
		try {
			return VL_GoogleDriveExplorerService.listChildrenForRecord(folderId, recordId);
		} catch (Exception ex) {
			FWERR_ErrorHandler.insertError(ex);
			throw new AuraHandledException(ex.getMessage());
		}
	}

	/**
	 * @name getExternalFileStatuses
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Returns traceability statuses for background polling without calling Google Drive.
	 * @param recordId Salesforce record Id represented by the folder.
	 * @param externalFileIds Traceability record Ids to query in bulk.
	 * @return List<VL_ExternalFileStatusDTO> current synchronization statuses.
	 */
	@AuraEnabled
	public static List<VL_ExternalFileStatusDTO> getExternalFileStatuses(Id recordId, List<Id> externalFileIds) {
		if (recordId == null || externalFileIds == null || externalFileIds.isEmpty()) {
			return new List<VL_ExternalFileStatusDTO>();
		}
		try {
			return VL_ExternalFileService.getExternalFileStatuses(recordId, new Set<Id>(externalFileIds));
		} catch (Exception ex) {
			FWERR_ErrorHandler.insertError(ex);
			throw new AuraHandledException(ex.getMessage());
		}
	}
}