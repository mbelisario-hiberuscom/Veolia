/**
 * @name VL_ExternalFileDTO
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description DTO returned by VL_GoogleDriveFilesController to the LWC.
 */
public inherited sharing class VL_ExternalFileDTO {
	@AuraEnabled
	public String id { get; set; }
	@AuraEnabled
	public String fileName { get; set; }
	@AuraEnabled
	public DateTime uploadedDate { get; set; }
	@AuraEnabled
	public String status { get; set; }
	@AuraEnabled
	public String remoteLinkUrl { get; set; }

	public VL_ExternalFileDTO(VL_ExternalFile__c record) {
		this.id = record.Id;
		this.fileName = record.Name;
		this.uploadedDate = record.VL_UploadedDate__c;
		this.status = record.VL_Status__c;
		this.remoteLinkUrl = record.VL_RemoteLinkUrl__c;
	}
}