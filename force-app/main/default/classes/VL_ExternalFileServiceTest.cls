/**
 * @name VL_ExternalFileServiceTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_ExternalFileService traceability record lifecycle.
 **/
@IsTest
private class VL_ExternalFileServiceTest {
	@TestSetup
	static void setupData() {
		User testUser = VL_TestDataFactory.createGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TestDataFactory.createAccount('ExternalFileService Test Account', null);
		}
	}

	private static VL_TransferRequest buildRequest(String docId, String versionId) {
		Account acc = [SELECT Id FROM Account WHERE Name = 'ExternalFileService Test Account' LIMIT 1];
		return new VL_TransferRequest(acc.Id, 'Account', 'Test Acc', docId, versionId, 'doc.pdf', 'application/pdf');
	}

	/**
	 * @name: createPendingRecordsSetsStatusAndLogicalKey
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies createPendingRecords inserts records with Pending status and correct logical key.
	 */
	@IsTest
	static void createPendingRecordsSetsStatusAndLogicalKey() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TransferRequest req = buildRequest('doc001', 'ver001');

			Test.startTest();
			List<VL_ExternalFile__c> inserted = VL_ExternalFileService.createPendingRecords(new List<VL_TransferRequest>{ req });
			Test.stopTest();

			System.assertEquals(1, inserted.size(), 'One record should be inserted');
			VL_ExternalFile__c rec = [
				SELECT VL_Status__c, VL_LogicalKey__c, VL_ContentDocumentId__c
				FROM VL_ExternalFile__c
				WHERE Id = :inserted[0].Id
			];
			System.assertEquals('Pending', rec.VL_Status__c, 'Status should be Pending');
			System.assertEquals('doc001:ver001', rec.VL_LogicalKey__c, 'Logical key should match');
			System.assertEquals('doc001', rec.VL_ContentDocumentId__c, 'Content document Id should match');
		}
	}

	/**
	 * @name: findCompletedKeysReturnsOnlyCompleted
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies findCompletedKeys only returns keys for Completed records.
	 */
	@IsTest
	static void findCompletedKeysReturnsOnlyCompleted() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TransferRequest req = buildRequest('doc002', 'ver002');
			List<VL_ExternalFile__c> inserted = VL_ExternalFileService.createPendingRecords(new List<VL_TransferRequest>{ req });
			VL_ExternalFileService.markCompleted(inserted[0].Id, 'remoteFile1', 'remoteFolder1', 'https://drive.google.com/file/d/1/view');

			Test.startTest();
			Set<String> completedKeys = VL_ExternalFileService.findCompletedKeys(new Set<String>{ 'doc002:ver002', 'doc999:ver999' });
			Test.stopTest();

			System.assert(completedKeys.contains('doc002:ver002'), 'Completed key should be returned');
			System.assert(!completedKeys.contains('doc999:ver999'), 'Non-existent key should not be returned');
		}
	}

	/**
	 * @name: markCompletedTransitionsStatusAndPersistsRemoteData
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies markCompleted sets status to Completed and stores remote identifiers.
	 */
	@IsTest
	static void markCompletedTransitionsStatusAndPersistsRemoteData() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TransferRequest req = buildRequest('doc003', 'ver003');
			List<VL_ExternalFile__c> inserted = VL_ExternalFileService.createPendingRecords(new List<VL_TransferRequest>{ req });

			Test.startTest();
			VL_ExternalFileService.markCompleted(inserted[0].Id, 'fileXYZ', 'folderXYZ', 'https://drive.google.com/file/d/xyz/view');
			Test.stopTest();

			VL_ExternalFile__c updated = [
				SELECT VL_Status__c, VL_RemoteFileId__c, VL_RemoteFolderId__c, VL_RemoteLinkUrl__c
				FROM VL_ExternalFile__c
				WHERE Id = :inserted[0].Id
			];
			System.assertEquals('Completed', updated.VL_Status__c, 'Status should be Completed');
			System.assertEquals('fileXYZ', updated.VL_RemoteFileId__c, 'Remote file Id should match');
			System.assertEquals('folderXYZ', updated.VL_RemoteFolderId__c, 'Remote folder Id should match');
			System.assertEquals('https://drive.google.com/file/d/xyz/view', updated.VL_RemoteLinkUrl__c, 'Remote link should match');
		}
	}

	/**
	 * @name: markErrorSetsStatusAndDiagnostic
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies markError transitions to Error and stores the diagnostic message.
	 */
	@IsTest
	static void markErrorSetsStatusAndDiagnostic() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TransferRequest req = buildRequest('doc004', 'ver004');
			List<VL_ExternalFile__c> inserted = VL_ExternalFileService.createPendingRecords(new List<VL_TransferRequest>{ req });

			Test.startTest();
			VL_ExternalFileService.markError(inserted[0].Id, 'Authentication failure');
			Test.stopTest();

			VL_ExternalFile__c updated = [SELECT VL_Status__c, VL_LastErrorTxtArea__c FROM VL_ExternalFile__c WHERE Id = :inserted[0].Id];
			System.assertEquals('Error', updated.VL_Status__c, 'Status should be Error');
			System.assertEquals('Authentication failure', updated.VL_LastErrorTxtArea__c, 'Error message should match');
		}
	}

	/**
	 * @name: incrementRetryIncrementsCount
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies incrementRetry increases the retry count by one.
	 */
	@IsTest
	static void incrementRetryIncrementsCount() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TransferRequest req = buildRequest('doc005', 'ver005');
			List<VL_ExternalFile__c> inserted = VL_ExternalFileService.createPendingRecords(new List<VL_TransferRequest>{ req });

			Test.startTest();
			VL_ExternalFileService.incrementRetry(inserted[0].Id);
			VL_ExternalFileService.incrementRetry(inserted[0].Id);
			Test.stopTest();

			VL_ExternalFile__c updated = [SELECT VL_RetryCountNumber__c FROM VL_ExternalFile__c WHERE Id = :inserted[0].Id];
			System.assertEquals(2, (Integer) updated.VL_RetryCountNumber__c, 'Retry count should be 2 after two increments');
		}
	}

	/**
	 * @name: createPendingRecordsBulk200SingleDml
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies 200 pending records are inserted with a single DML statement.
	 */
	@IsTest
	static void createPendingRecordsBulk200SingleDml() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			Account acc = [SELECT Id FROM Account WHERE Name = 'ExternalFileService Test Account' LIMIT 1];
			List<VL_TransferRequest> requests = new List<VL_TransferRequest>();
			for (Integer i = 0; i < 200; i++) {
				requests.add(new VL_TransferRequest(acc.Id, 'Account', 'Acc', 'doc' + i, 'ver' + i, 'file' + i + '.pdf', 'application/pdf'));
			}

			Test.startTest();
			List<VL_ExternalFile__c> inserted = VL_ExternalFileService.createPendingRecords(requests);
			Integer dmlStatementsDuringBulk = Limits.getDmlStatements();
			Test.stopTest();

			System.assertEquals(200, inserted.size(), 'All 200 records should be inserted');
			System.assert(dmlStatementsDuringBulk <= 2, 'Should use one service DML statement plus at most one org automation DML statement');
		}
	}

	/**
	 * @name: findUnsyncedDriveItemsMatchesSelectedFolder
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies Pending, Error, and Manual Review traceability records are returned only for the selected upload folder.
	 */
	@IsTest
	static void findUnsyncedDriveItemsMatchesSelectedFolder() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			Account account = [SELECT Id FROM Account WHERE Name = 'ExternalFileService Test Account' LIMIT 1];
			ContentVersion pendingVersion = createContentVersion('Pending contract', 'CONTRACTS');
			ContentVersion errorVersion = createContentVersion('Error invoice', 'CONTRACTS');
			ContentVersion manualReviewVersion = createContentVersion('Manual review document', 'CONTRACTS');
			ContentVersion otherFolderVersion = createContentVersion('Other folder file', 'OTHER');
			ContentVersion completedVersion = createContentVersion('Completed contract', 'CONTRACTS');
			ContentVersion rootVersion = createContentVersion('Root pending file', null);

			insert new List<VL_ExternalFile__c>{
				buildTraceabilityRecord(account, pendingVersion, 'Pending', null),
				buildTraceabilityRecord(account, errorVersion, 'Error', 'Drive authentication failed'),
				buildTraceabilityRecord(account, manualReviewVersion, 'Manual Review', 'Document linked to multiple records'),
				buildTraceabilityRecord(account, otherFolderVersion, 'Pending', null),
				buildTraceabilityRecord(account, completedVersion, 'Completed', null),
				buildTraceabilityRecord(account, rootVersion, 'Pending', null)
			};

			Test.startTest();
			List<VL_DriveItemDTO> result = VL_ExternalFileService.findUnsyncedDriveItems(account.Id, 'CONTRACTS', 'ACCOUNT_ROOT');
			Test.stopTest();

			System.assertEquals(
				3,
				result.size(),
				'Only Pending, Error, and Manual Review records selected for the visible folder should be returned'
			);
			System.assertEquals('Pending', result[0].syncStatus, 'Pending status should be projected');
			System.assertEquals('Error', result[1].syncStatus, 'Error status should be projected');
			System.assertEquals('Drive authentication failed', result[1].syncError, 'Error diagnostic should be projected');
			System.assertEquals('Manual Review', result[2].syncStatus, 'Manual Review status should be projected');
			System.assertEquals('Document linked to multiple records', result[2].syncError, 'Manual Review diagnostic should be projected');
			System.assertEquals(false, result[0].isFolder, 'Unprocessed records should be file cards');

			List<VL_DriveItemDTO> rootResult = VL_ExternalFileService.findUnsyncedDriveItems(account.Id, 'ACCOUNT_ROOT', 'ACCOUNT_ROOT');
			System.assertEquals(1, rootResult.size(), 'A blank upload destination should appear only in the record root');
			System.assertEquals('Root pending file', rootResult[0].name, 'The blank destination should be represented in the root folder');
		}
	}

	/**
	 * @name: getExternalFileStatusesReturnsBulkCurrentStatus
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies background status polling returns current status and remote data for the requested parent.
	 */
	@IsTest
	static void getExternalFileStatusesReturnsBulkCurrentStatus() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			Account account = [SELECT Id FROM Account WHERE Name = 'ExternalFileService Test Account' LIMIT 1];
			ContentVersion version = createContentVersion('Status polling file', 'ACCOUNT_ROOT');
			VL_ExternalFile__c traceRecord = buildTraceabilityRecord(account, version, 'Completed', null);
			traceRecord.VL_RemoteFileId__c = 'REMOTE_FILE';
			traceRecord.VL_RemoteLinkUrl__c = 'https://drive.google.com/file/d/remote/view';
			insert traceRecord;

			Test.startTest();
			List<VL_ExternalFileStatusDTO> result = VL_ExternalFileService.getExternalFileStatuses(account.Id, new Set<Id>{ traceRecord.Id });
			Test.stopTest();

			System.assertEquals(1, result.size(), 'One requested status should be returned');
			System.assertEquals(String.valueOf(traceRecord.Id), result[0].externalFileId, 'Traceability Id should be returned');
			System.assertEquals('Completed', result[0].status, 'Current status should be returned');
			System.assertEquals('REMOTE_FILE', result[0].remoteFileId, 'Remote file Id should be returned');
			System.assertEquals('https://drive.google.com/file/d/remote/view', result[0].remoteLinkUrl, 'Remote link should be returned');
		}
	}

	/**
	 * @name: markManualReviewSetsStatus
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies markManualReview transitions to Manual Review status.
	 */
	@IsTest
	static void markManualReviewSetsStatus() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TransferRequest req = buildRequest('doc006', 'ver006');
			List<VL_ExternalFile__c> inserted = VL_ExternalFileService.createPendingRecords(new List<VL_TransferRequest>{ req });

			Test.startTest();
			VL_ExternalFileService.markManualReview(inserted[0].Id, 'Document linked to multiple records');
			Test.stopTest();

			VL_ExternalFile__c updated = [SELECT VL_Status__c FROM VL_ExternalFile__c WHERE Id = :inserted[0].Id];
			System.assertEquals('Manual Review', updated.VL_Status__c, 'Status should be Manual Review');
		}
	}

	private static ContentVersion createContentVersion(String title, String folderId) {
		ContentVersion version = new ContentVersion(
			Title = title,
			PathOnClient = title + '.pdf',
			VersionData = Blob.valueOf('test file'),
			VL_GoogleDriveFolder_fileupload__c = folderId
		);
		insert version;
		return [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :version.Id];
	}

	private static VL_ExternalFile__c buildTraceabilityRecord(Account account, ContentVersion version, String status, String errorMessage) {
		return new VL_ExternalFile__c(
			VL_ParentRecordId__c = String.valueOf(account.Id),
			VL_ParentObjectApiName__c = 'Account',
			VL_ContentDocumentId__c = String.valueOf(version.ContentDocumentId),
			VL_ContentVersionId__c = String.valueOf(version.Id),
			VL_LogicalKey__c = String.valueOf(version.ContentDocumentId) + ':' + String.valueOf(version.Id),
			VL_Status__c = status,
			VL_LastErrorTxtArea__c = errorMessage,
			VL_RetryCountNumber__c = 0
		);
	}
}