/**
 * @name VL_GoogleDriveConfigDTO
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Data transfer object carrying parsed configuration from VL_GoogleDriveConfiguration__mdt.
 */
public inherited sharing class VL_GoogleDriveConfigDTO {
	/** Google Drive root folder Id (personal drive or shared drive root). */
	public String rootFolderId;
	/** Google Shared Drive Id; blank when using personal drive. */
	public String sharedDriveId;
	/** Lowercase API names of objects enabled for the integration. */
	public List<String> enabledObjects;
	/** Maximum retry attempts for recoverable errors. */
	public Integer maxRetries;
	/** When true, Salesforce Files binary is deleted after successful single-record upload. */
	public Boolean autoCleanup;
	/** Folder naming pattern using {RecordId} and {RecordName} tokens. */
	public String folderNamingPattern;
	/** When false, the integration is disabled and no jobs are enqueued. */
	public Boolean isActive;
	/** Maximum file size in decimal MB; files above this limit are not uploaded. */
	public Decimal maxFileSizeMb;

	/**
	 * @name VL_GoogleDriveConfigDTO
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates an empty configuration DTO for incremental mapping.
	 */
	public VL_GoogleDriveConfigDTO() {
		this.rootFolderId = null;
		this.sharedDriveId = null;
		this.enabledObjects = null;
		this.maxRetries = null;
		this.autoCleanup = null;
		this.folderNamingPattern = null;
		this.isActive = null;
		this.maxFileSizeMb = null;
	}

	/**
	 * @name VL_GoogleDriveConfigDTO
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates a configuration DTO with all values initialized.
	 * @param rootFolderId Google Drive root folder Id.
	 * @param sharedDriveId Google Shared Drive Id.
	 * @param enabledObjects Lowercase API names of enabled objects.
	 * @param maxRetries Maximum retry attempts.
	 * @param autoCleanup Whether uploaded Salesforce Files are deleted.
	 * @param folderNamingPattern Folder naming pattern.
	 * @param isActive Whether the integration is active.
	 * @param maxFileSizeMb Maximum file size in decimal MB.
	 */
	public VL_GoogleDriveConfigDTO(
		String rootFolderId,
		String sharedDriveId,
		List<String> enabledObjects,
		Integer maxRetries,
		Boolean autoCleanup,
		String folderNamingPattern,
		Boolean isActive,
		Decimal maxFileSizeMb
	) {
		this.rootFolderId = rootFolderId;
		this.sharedDriveId = sharedDriveId;
		this.enabledObjects = enabledObjects;
		this.maxRetries = maxRetries;
		this.autoCleanup = autoCleanup;
		this.folderNamingPattern = folderNamingPattern;
		this.isActive = isActive;
		this.maxFileSizeMb = maxFileSizeMb;
	}
}