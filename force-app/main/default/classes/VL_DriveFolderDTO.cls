/**
 * @name VL_DriveFolderDTO
 * @version 1.0
 * @creation date: 01/09/2026
 * @author: Jesus Piriz
 * @description Result of resolving a Salesforce record to its live Google Drive folder. The
 *              folderId is null when the record folder does not yet exist in Drive.
 */
public with sharing class VL_DriveFolderDTO {
	@AuraEnabled
	public String folderId;

	@AuraEnabled
	public String folderName;

	/**
	 * @name VL_DriveFolderDTO
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates an empty folder DTO for incremental mapping.
	 */
	public VL_DriveFolderDTO() {
		this.folderId = null;
		this.folderName = null;
	}

	/**
	 * @name VL_DriveFolderDTO
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates a folder DTO with its identity and display name.
	 * @param folderId Google Drive folder Id.
	 * @param folderName Folder display name.
	 */
	public VL_DriveFolderDTO(String folderId, String folderName) {
		this.folderId = folderId;
		this.folderName = folderName;
	}
}