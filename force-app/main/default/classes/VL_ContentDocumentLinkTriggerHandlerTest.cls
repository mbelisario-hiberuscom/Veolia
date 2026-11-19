/**
 * @name VL_ContentDocumentLinkTriggerHandlerTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_ContentDocumentLinkTriggerHandler interface compliance and delegation.
 */
@IsTest
private class VL_ContentDocumentLinkTriggerHandlerTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	/**
	 * @name afterInsertDelegatesToHelper
	 * @description Verifies that afterInsert accumulates records and finallyAfterInsert delegates to helper.
	 */
	@IsTest
	static void afterInsertDelegatesToHelper() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Account acc = VL_TestDataFactory.createAccount('Handler Test Account', null);
			VL_GoogleDriveConfigDTO cfg = new VL_GoogleDriveConfigDTO();
			cfg.isActive = false;
			VL_GoogleDriveConfigSelector.cachedConfig = cfg;

			ContentVersion cv = new ContentVersion(
				Title = 'HandlerDoc',
				PathOnClient = 'HandlerDoc.pdf',
				VersionData = Blob.valueOf('handler test'),
				IsMajorVersion = true
			);
			insert cv;
			cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

			ContentDocumentLink link = new ContentDocumentLink(
				ContentDocumentId = cv.ContentDocumentId,
				LinkedEntityId = acc.Id,
				ShareType = 'V'
			);
			insert link;

			VL_ContentDocumentLinkTriggerHandler handler = new VL_ContentDocumentLinkTriggerHandler();
			handler.bulkAfterInsert();
			handler.afterInsert(link);

			Test.startTest();
			handler.finallyAfterInsert();
			Test.stopTest();

			// Config inactive → no enqueue; no exception = helper was called without error
			System.assertEquals(0, Limits.getQueueableJobs(), 'No queueable for inactive config');
		}
	}

	/**
	 * @name inertMethodsDoNotThrow
	 * @description All other interface methods are inert and must not throw.
	 */
	@IsTest
	static void inertMethodsDoNotThrow() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_ContentDocumentLinkTriggerHandler handler = new VL_ContentDocumentLinkTriggerHandler();
			Account acc = new Account(Name = 'Inert Test');
			Boolean threw = false;
			try {
				handler.bulkBeforeInsert();
				handler.bulkBeforeUpdate();
				handler.bulkBeforeDelete();
				handler.bulkAfterUpdate();
				handler.bulkAfterDelete();
				handler.bulkAfterUndelete();
				handler.beforeInsert(acc);
				handler.beforeUpdate(acc, acc);
				handler.beforeDelete(acc);
				handler.afterUpdate(acc, acc);
				handler.afterDelete(acc);
				handler.afterUndelete(acc);
				handler.finallyBeforeInsert();
				handler.finallyBeforeUpdate();
				handler.finallyBeforeDelete();
				handler.finallyAfterUpdate();
				handler.finallyAfterDelete();
				handler.finallyAfterUndelete();
			} catch (Exception ex) {
				threw = true;
			}
			System.assert(!threw, 'Inert methods should not throw');
		}
	}
}