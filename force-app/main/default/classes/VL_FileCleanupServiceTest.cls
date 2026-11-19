/**
 * @name VL_FileCleanupServiceTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_FileCleanupService binary deletion decision logic.
 **/
@IsTest
private class VL_FileCleanupServiceTest {
	private static final String TEST_ACCOUNT_NAME = 'Test Account 1';

	@TestSetup
	static void setupData() {
		User testUser = VL_TestDataFactory.createGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_CNAE__c cnae = VL_TestDataFactory.createCNAE(null);
			VL_TestDataFactory.createAccount(TEST_ACCOUNT_NAME, cnae);
		}
	}

	private static VL_GoogleDriveConfigDTO buildConfig(Boolean autoCleanup) {
		VL_GoogleDriveConfigDTO cfg = new VL_GoogleDriveConfigDTO();
		cfg.isActive = true;
		cfg.autoCleanup = autoCleanup;
		cfg.rootFolderId = 'root1';
		cfg.maxRetries = 3;
		cfg.enabledObjects = new List<String>{ 'account' };
		cfg.maxFileSizeMb = 25;
		return cfg;
	}

	private static VL_ExternalFile__c insertCompletedRecord(Id parentId, String docId, String versionId) {
		VL_ExternalFile__c rec = new VL_ExternalFile__c(
			VL_ParentRecordId__c = String.valueOf(parentId),
			VL_ParentObjectApiName__c = 'Account',
			VL_ContentDocumentId__c = docId,
			VL_ContentVersionId__c = versionId,
			VL_LogicalKey__c = docId + ':' + versionId,
			VL_Status__c = 'Completed',
			VL_RemoteFileId__c = 'remoteFile1',
			VL_RemoteFolderId__c = 'remoteFolder1',
			VL_RemoteLinkUrl__c = 'https://drive.google.com/file/d/1/view'
		);
		insert rec;
		return rec;
	}

	/**
	 * @name: cleanupSkipsWhenAutoCleanupDisabled
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies no deletion occurs when autoCleanup flag is false in config.
	 */
	@IsTest
	static void cleanupSkipsWhenAutoCleanupDisabled() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildConfig(false);
			Account acc = [SELECT Id FROM Account WHERE Name = :TEST_ACCOUNT_NAME LIMIT 1];
			VL_ExternalFile__c rec = insertCompletedRecord(acc.Id, 'docDisabled1', 'verDisabled1');

			Test.startTest();
			VL_FileCleanupService.cleanupIfSafe(new List<Id>{ rec.Id });
			Test.stopTest();

			VL_ExternalFile__c updated = [SELECT VL_IsSourceDeleted__c, VL_Status__c FROM VL_ExternalFile__c WHERE Id = :rec.Id];
			System.assertEquals(false, updated.VL_IsSourceDeleted__c, 'Source deleted flag should remain false when cleanup is disabled');
			System.assertEquals('Completed', updated.VL_Status__c, 'Status should remain Completed');
		}
	}

	/**
	 * @name: cleanupSkipsWhenMultipleLinksAndSetsManualReview
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a document linked to multiple records is not deleted and is set to Manual Review.
	 */
	@IsTest
	static void cleanupSkipsWhenMultipleLinksAndSetsManualReview() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildConfig(true);
			Account acc = [SELECT Id FROM Account WHERE Name = :TEST_ACCOUNT_NAME LIMIT 1];

			// Create a content note linked to the account and also to another record (the account again simulates multi-link)
			ContentNote cn = new ContentNote(Title = 'Multi-link test note', Content = Blob.valueOf('test'));
			insert cn;
			ContentDocumentLink link1 = new ContentDocumentLink(ContentDocumentId = cn.Id, LinkedEntityId = acc.Id, ShareType = 'V');
			insert link1;
			// Link to another lead record to simulate multi-record link
			Lead ld = VL_TestDataFactory.createLead('Test', 'MultiLink', 'TestCo', 'ml@test.com');
			ContentDocumentLink link2 = new ContentDocumentLink(ContentDocumentId = cn.Id, LinkedEntityId = ld.Id, ShareType = 'V');
			insert link2;

			VL_ExternalFile__c rec = insertCompletedRecord(acc.Id, String.valueOf(cn.Id), 'verMulti1');

			Test.startTest();
			VL_FileCleanupService.cleanupIfSafe(new List<Id>{ rec.Id });
			Test.stopTest();

			VL_ExternalFile__c updated = [SELECT VL_Status__c, VL_IsSourceDeleted__c FROM VL_ExternalFile__c WHERE Id = :rec.Id];
			System.assertEquals('Manual Review', updated.VL_Status__c, 'Multi-linked document should be set to Manual Review');
			System.assertEquals(false, updated.VL_IsSourceDeleted__c, 'Source deleted flag should remain false');
		}
	}

	/**
	 * @name: cleanupIgnoresImplicitUserLink
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that Salesforce's implicit User link does not prevent cleanup for a single Account link.
	 */
	@IsTest
	static void cleanupIgnoresImplicitUserLink() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildConfig(true);
			Account acc = [SELECT Id FROM Account WHERE Name = :TEST_ACCOUNT_NAME LIMIT 1];
			ContentNote cn = new ContentNote(Title = 'Implicit user link test note', Content = Blob.valueOf('test'));
			insert cn;
			ContentDocumentLink accountLink = new ContentDocumentLink(ContentDocumentId = cn.Id, LinkedEntityId = acc.Id, ShareType = 'V');
			insert accountLink;
			VL_ExternalFile__c rec = insertCompletedRecord(acc.Id, String.valueOf(cn.Id), 'verSingle1');

			Test.startTest();
			VL_FileCleanupService.cleanupIfSafe(new List<Id>{ rec.Id });
			Test.stopTest();

			VL_ExternalFile__c updated = [SELECT VL_Status__c, VL_IsSourceDeleted__c FROM VL_ExternalFile__c WHERE Id = :rec.Id];
			System.assertEquals('Completed', updated.VL_Status__c, 'Single-record cleanup should keep the Completed status');
			System.assertEquals(true, updated.VL_IsSourceDeleted__c, 'Implicit User link should not block source deletion');
			System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :cn.Id], 'ContentDocument should be deleted');
		}
	}

	/**
	 * @name: cleanupHandlesEmptyListGracefully
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies cleanupIfSafe handles an empty list without error.
	 */
	@IsTest
	static void cleanupHandlesEmptyListGracefully() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildConfig(true);
			Integer dmlStatementsBeforeCleanup = Limits.getDmlStatements();
			Test.startTest();
			VL_FileCleanupService.cleanupIfSafe(new List<Id>());
			Test.stopTest();
			System.assertEquals(dmlStatementsBeforeCleanup, Limits.getDmlStatements(), 'No DML should occur for empty list');
		}
	}
}