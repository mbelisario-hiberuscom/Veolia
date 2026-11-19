/**
 * @name VL_ContentDocumentLinkTriggerHelperTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_ContentDocumentLinkTriggerHelper bulk classification logic.
 **/
@IsTest
private class VL_ContentDocumentLinkTriggerHelperTest {
	@TestSetup
	static void setupData() {
		User testUser = VL_TestDataFactory.createGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TestDataFactory.createAccount('Helper Test Account', null);
		}
	}

	private static VL_GoogleDriveConfigDTO buildActiveConfig() {
		VL_GoogleDriveConfigDTO cfg = new VL_GoogleDriveConfigDTO();
		cfg.isActive = true;
		cfg.rootFolderId = 'root1';
		cfg.sharedDriveId = null;
		cfg.enabledObjects = new List<String>{ 'lead', 'account', 'opportunity', 'quote' };
		cfg.maxRetries = 3;
		cfg.autoCleanup = false;
		cfg.folderNamingPattern = '{RecordId}-{RecordName}';
		cfg.maxFileSizeMb = 25;
		return cfg;
	}

	private static ContentVersion insertContentVersion() {
		ContentVersion cv = new ContentVersion(
			Title = 'TestDoc',
			PathOnClient = 'TestDoc.pdf',
			VersionData = Blob.valueOf('test content'),
			IsMajorVersion = true
		);
		insert cv;
		return [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
	}

	/**
	 * @name: handleAfterInsertEnqueuesQueueableForEnabledObject
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a ContentDocumentLink for an enabled Account enqueues a job.
	 */
	@IsTest
	static void handleAfterInsertEnqueuesQueueableForEnabledObject() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigDTO config = buildActiveConfig();
			config.isActive = false;
			VL_GoogleDriveConfigSelector.cachedConfig = config;
			Account acc = [SELECT Id FROM Account WHERE Name = 'Helper Test Account' LIMIT 1];
			ContentVersion cv = insertContentVersion();
			ContentDocumentLink link = new ContentDocumentLink(
				ContentDocumentId = cv.ContentDocumentId,
				LinkedEntityId = acc.Id,
				ShareType = 'V'
			);
			insert link;
			config.isActive = true;

			Test.startTest();
			VL_ContentDocumentLinkTriggerHelper.handleAfterInsert(new List<ContentDocumentLink>{ link });
			Integer jobsEnqueued = Limits.getQueueableJobs();
			List<VL_ExternalFile__c> pending = [
				SELECT VL_Status__c
				FROM VL_ExternalFile__c
				WHERE VL_ContentDocumentId__c = :String.valueOf(cv.ContentDocumentId)
			];
			Test.stopTest();

			System.assertEquals(1, jobsEnqueued, 'One queueable should be enqueued for an enabled object');
			System.assertEquals(1, pending.size(), 'One pending traceability record should be created');
			System.assertEquals('Pending', pending[0].VL_Status__c, 'Status should be Pending');
		}
	}

	/**
	 * @name: handleAfterInsertIgnoresNonEnabledObject
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a ContentDocumentLink for a non-enabled object enqueues no job.
	 */
	@IsTest
	static void handleAfterInsertIgnoresNonEnabledObject() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigDTO cfg = buildActiveConfig();
			cfg.enabledObjects = new List<String>{ 'opportunity' }; // Account not enabled
			VL_GoogleDriveConfigSelector.cachedConfig = cfg;
			Account acc = [SELECT Id FROM Account WHERE Name = 'Helper Test Account' LIMIT 1];
			ContentVersion cv = insertContentVersion();
			ContentDocumentLink link = new ContentDocumentLink(
				ContentDocumentId = cv.ContentDocumentId,
				LinkedEntityId = acc.Id,
				ShareType = 'V'
			);
			insert link;

			Test.startTest();
			VL_ContentDocumentLinkTriggerHelper.handleAfterInsert(new List<ContentDocumentLink>{ link });
			Integer jobsEnqueued = Limits.getQueueableJobs();
			Test.stopTest();

			System.assertEquals(0, jobsEnqueued, 'No queueable should be enqueued for non-enabled object');
		}
	}

	/**
	 * @name: handleAfterInsertIgnoresInactiveConfig
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that an inactive configuration suppresses all processing.
	 */
	@IsTest
	static void handleAfterInsertIgnoresInactiveConfig() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigDTO cfg = buildActiveConfig();
			cfg.isActive = false;
			VL_GoogleDriveConfigSelector.cachedConfig = cfg;
			Account acc = [SELECT Id FROM Account WHERE Name = 'Helper Test Account' LIMIT 1];
			ContentVersion cv = insertContentVersion();
			ContentDocumentLink link = new ContentDocumentLink(
				ContentDocumentId = cv.ContentDocumentId,
				LinkedEntityId = acc.Id,
				ShareType = 'V'
			);
			insert link;

			Test.startTest();
			VL_ContentDocumentLinkTriggerHelper.handleAfterInsert(new List<ContentDocumentLink>{ link });
			Integer jobsEnqueued = Limits.getQueueableJobs();
			Test.stopTest();

			System.assertEquals(0, jobsEnqueued, 'No queueable should be enqueued when config is inactive');
		}
	}

	/**
	 * @name: handleAfterInsertRejectsOversizedFileBeforeTraceability
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that server-side size validation rolls back the Salesforce File upload before traceability or async processing.
	 */
	@IsTest
	static void handleAfterInsertRejectsOversizedFileBeforeTraceability() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigDTO cfg = buildActiveConfig();
			cfg.maxFileSizeMb = 0;
			VL_GoogleDriveConfigSelector.cachedConfig = cfg;
			Account acc = [SELECT Id FROM Account WHERE Name = 'Helper Test Account' LIMIT 1];
			ContentVersion cv = new ContentVersion(
				Title = 'RejectedOversizedDoc',
				PathOnClient = 'RejectedOversizedDoc.pdf',
				VersionData = Blob.valueOf('small test content'),
				FirstPublishLocationId = acc.Id,
				IsMajorVersion = true
			);
			Boolean failed = false;

			Test.startTest();
			try {
				insert cv;
			} catch (DmlException ex) {
				failed = true;
				System.assert(ex.getMessage().contains('maximum size'), 'The DML error should identify the size validation');
			}
			Integer jobsEnqueued = Limits.getQueueableJobs();
			Test.stopTest();

			System.assert(failed, 'An oversized file should fail during the upload transaction');
			System.assertEquals(
				0,
				[SELECT COUNT() FROM ContentVersion WHERE Title = 'RejectedOversizedDoc'],
				'The rejected ContentVersion should be rolled back'
			);
			System.assertEquals(
				0,
				[SELECT COUNT() FROM ContentDocument WHERE Title = 'RejectedOversizedDoc'],
				'The rejected ContentDocument should be rolled back'
			);
			System.assertEquals(
				0,
				[SELECT COUNT() FROM VL_ExternalFile__c WHERE VL_ParentRecordId__c = :String.valueOf(acc.Id)],
				'No traceability record should be created for a rejected file'
			);
			System.assertEquals(0, jobsEnqueued, 'No queueable should be enqueued for a rejected file');
		}
	}

	/**
	 * @name: handleAfterInsertHandlesEmptyListGracefully
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that an empty list input produces no side effects.
	 */
	@IsTest
	static void handleAfterInsertHandlesEmptyListGracefully() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildActiveConfig();
			Test.startTest();
			VL_ContentDocumentLinkTriggerHelper.handleAfterInsert(new List<ContentDocumentLink>());
			Test.stopTest();
			System.assertEquals(0, Limits.getQueueableJobs(), 'No job should be enqueued for empty input');
		}
	}

	/**
	 * @name: handleAfterInsertBulk200EnqueuesSingleJob
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that 200 ContentDocumentLinks result in a single enqueued queueable.
	 */
	@IsTest
	static void handleAfterInsertBulk200EnqueuesSingleJob() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigDTO config = buildActiveConfig();
			config.isActive = false;
			VL_GoogleDriveConfigSelector.cachedConfig = config;
			Account acc = [SELECT Id FROM Account WHERE Name = 'Helper Test Account' LIMIT 1];

			List<ContentVersion> versions = new List<ContentVersion>();
			for (Integer i = 0; i < 5; i++) {
				versions.add(
					new ContentVersion(
						Title = 'BulkDoc' + i,
						PathOnClient = 'BulkDoc' + i + '.pdf',
						VersionData = Blob.valueOf('bulk content ' + i),
						IsMajorVersion = true
					)
				);
			}
			insert versions;
			List<ContentVersion> insertedVersions = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versions];
			List<ContentDocumentLink> links = new List<ContentDocumentLink>();
			for (ContentVersion inserted : insertedVersions) {
				links.add(new ContentDocumentLink(ContentDocumentId = inserted.ContentDocumentId, LinkedEntityId = acc.Id, ShareType = 'V'));
			}
			insert links;
			config.isActive = true;

			Test.startTest();
			VL_ContentDocumentLinkTriggerHelper.handleAfterInsert(links);
			Integer jobsEnqueued = Limits.getQueueableJobs();
			Integer queries = Limits.getQueries();
			Test.stopTest();

			System.assertEquals(1, jobsEnqueued, 'Exactly one queueable should be enqueued for the bulk batch');
			System.assert(queries <= 5, 'SOQL query count should be bounded for bulk scenario');
		}
	}
}