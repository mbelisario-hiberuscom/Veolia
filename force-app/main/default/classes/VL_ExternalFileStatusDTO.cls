/**
 * @name VL_ExternalFileStatusDTO
 * @version 1.0
 * @creation date: 03/09/2026
 * @author: Jesus Piriz
 * @description Lightweight status projection for background synchronization polling.
 */
public with sharing class VL_ExternalFileStatusDTO {
	@AuraEnabled
	public String externalFileId;

	@AuraEnabled
	public String status;

	@AuraEnabled
	public String error;

	@AuraEnabled
	public String remoteFileId;

	@AuraEnabled
	public String remoteLinkUrl;

	/**
	 * @name VL_ExternalFileStatusDTO
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates an empty external-file status DTO for incremental mapping.
	 */
	public VL_ExternalFileStatusDTO() {
		this.externalFileId = null;
		this.status = null;
		this.error = null;
		this.remoteFileId = null;
		this.remoteLinkUrl = null;
	}

	/**
	 * @name VL_ExternalFileStatusDTO
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates an external-file status DTO with all status values initialized.
	 * @param externalFileId Salesforce external-file record Id.
	 * @param status Synchronization status.
	 * @param error Synchronization error message.
	 * @param remoteFileId Google Drive file Id.
	 * @param remoteLinkUrl Google Drive file URL.
	 */
	public VL_ExternalFileStatusDTO(String externalFileId, String status, String error, String remoteFileId, String remoteLinkUrl) {
		this.externalFileId = externalFileId;
		this.status = status;
		this.error = error;
		this.remoteFileId = remoteFileId;
		this.remoteLinkUrl = remoteLinkUrl;
	}
}