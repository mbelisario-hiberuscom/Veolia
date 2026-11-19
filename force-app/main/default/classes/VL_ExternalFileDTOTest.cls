/**
 * @name VL_ExternalFileDTOTest
 * @version 1.0
 * @creation date: 01/09/2026
 * @author: Jesus Piriz
 * @description Tests for VL_ExternalFileDTO field mapping.
 */
@IsTest
private class VL_ExternalFileDTOTest {
	/**
	 * @name: constructorMapsExternalFileFields
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that the DTO maps all exposed fields from an external file record.
	 */
	@IsTest
	static void constructorMapsExternalFileFields() {
		DateTime uploadedDate = DateTime.now();
		VL_ExternalFile__c record = new VL_ExternalFile__c(
			VL_ParentRecordId__c = '001000000000001AAA',
			VL_ParentObjectApiName__c = 'Account',
			VL_ContentDocumentId__c = 'test-document',
			VL_ContentVersionId__c = 'test-version',
			VL_LogicalKey__c = 'test-document:test-version',
			VL_UploadedDate__c = uploadedDate,
			VL_Status__c = 'Completed',
			VL_RetryCountNumber__c = 0,
			VL_RemoteLinkUrl__c = 'https://drive.google.com/file/d/test/view'
		);
		insert record;

		Test.startTest();
		VL_ExternalFileDTO result = new VL_ExternalFileDTO(record);
		Test.stopTest();

		System.assertEquals(record.Id, result.id, 'Record Id should be mapped');
		System.assertEquals(record.Name, result.fileName, 'Generated file name should be mapped');
		System.assertEquals(uploadedDate, result.uploadedDate, 'Uploaded date should be mapped');
		System.assertEquals('Completed', result.status, 'Status should be mapped');
		System.assertEquals('https://drive.google.com/file/d/test/view', result.remoteLinkUrl, 'Remote link should be mapped');
	}
}