/**
 * @name VL_GoogleDriveSubfolderConfigDTO
 * @version 1.0
 * @creation date: 02/09/2026
 * @author: Jesus Piriz
 * @description Represents one administrator-configured Google Drive subfolder.
 */
public inherited sharing class VL_GoogleDriveSubfolderConfigDTO {
	/** Salesforce object API name to which the subfolder applies. */
	public String objectApiName;
	/** Google Drive subfolder name. */
	public String folderName;
	/** Display and creation order among subfolders. */
	public Integer orderNumber;
	/** Whether this subfolder configuration is active. */
	public Boolean isActive;

	/**
	 * @name VL_GoogleDriveSubfolderConfigDTO
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Constructs a subfolder configuration DTO.
	 * @param objectApiName Salesforce object API name.
	 * @param folderName Google Drive subfolder name.
	 * @param orderNumber Display and creation order.
	 * @param isActive Whether the configuration is active.
	 */
	public VL_GoogleDriveSubfolderConfigDTO(String objectApiName, String folderName, Integer orderNumber, Boolean isActive) {
		this.objectApiName = objectApiName;
		this.folderName = folderName;
		this.orderNumber = orderNumber;
		this.isActive = isActive;
	}
}