/**
 * @name VL_DriveItemDTO
 * @version 1.0
 * @creation date: 01/09/2026
 * @author: Jesus Piriz
 * @description Lightweight projection of a live Google Drive entry (file or folder) for the
 *              vl_GoogleDriveFiles explorer. Size is exposed in bytes; the LWC formats it to MB.
 */
public with sharing class VL_DriveItemDTO {
	@AuraEnabled
	public String id;

	@AuraEnabled
	public String name;

	@AuraEnabled
	public Boolean isFolder;

	@AuraEnabled
	public Boolean isLinkedFolder;

	@AuraEnabled
	public Boolean isReadOnly;

	@AuraEnabled
	public String mimeType;

	@AuraEnabled
	public Long sizeBytes;

	@AuraEnabled
	public String modifiedTime;

	@AuraEnabled
	public String webViewLink;

	@AuraEnabled
	public String syncStatus;

	@AuraEnabled
	public String syncError;

	@AuraEnabled
	public String externalFileId;

	/**
	 * @name VL_DriveItemDTO
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates an empty Drive item DTO for incremental mapping.
	 */
	public VL_DriveItemDTO() {
		this.id = null;
		this.name = null;
		this.isFolder = null;
		this.isLinkedFolder = null;
		this.isReadOnly = null;
		this.mimeType = null;
		this.sizeBytes = null;
		this.modifiedTime = null;
		this.webViewLink = null;
		this.syncStatus = null;
		this.syncError = null;
		this.externalFileId = null;
	}

	/**
	 * @name VL_DriveItemDTO
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates a Drive item DTO with all projection values initialized.
	 * @param id Google Drive entry Id.
	 * @param name Google Drive entry name.
	 * @param isFolder Whether the entry is a folder.
	 * @param isLinkedFolder Whether the folder is linked from another Salesforce record.
	 * @param isReadOnly Whether the entry is read-only.
	 * @param mimeType Google Drive MIME type.
	 * @param sizeBytes File size in bytes.
	 * @param modifiedTime Last modification timestamp.
	 * @param webViewLink Google Drive entry URL.
	 * @param syncStatus Salesforce synchronization status.
	 * @param syncError Salesforce synchronization error.
	 * @param externalFileId Salesforce external-file record Id.
	 */
	public VL_DriveItemDTO(
		String id,
		String name,
		Boolean isFolder,
		Boolean isLinkedFolder,
		Boolean isReadOnly,
		String mimeType,
		Long sizeBytes,
		String modifiedTime,
		String webViewLink,
		String syncStatus,
		String syncError,
		String externalFileId
	) {
		this.id = id;
		this.name = name;
		this.isFolder = isFolder;
		this.isLinkedFolder = isLinkedFolder;
		this.isReadOnly = isReadOnly;
		this.mimeType = mimeType;
		this.sizeBytes = sizeBytes;
		this.modifiedTime = modifiedTime;
		this.webViewLink = webViewLink;
		this.syncStatus = syncStatus;
		this.syncError = syncError;
		this.externalFileId = externalFileId;
	}
}