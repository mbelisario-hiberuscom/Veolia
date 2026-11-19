/**
 * @name VL_GoogleDriveUploadQueueableTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_GoogleDriveUploadQueueable async transfer execution and retry policy.
 **/
@IsTest
private class VL_GoogleDriveUploadQueueableTest {
	@TestSetup
	static void setupData() {
		User testUser = VL_TestDataFactory.createGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TestDataFactory.createAccount('Queueable Test Account', null);
		}
	}

	private static VL_GoogleDriveConfigDTO buildConfig(Integer maxRetries) {
		VL_GoogleDriveSubfolderConfigSelector.cachedByObject = new Map<String, List<VL_GoogleDriveSubfolderConfigDTO>>{
			'account' => new List<VL_GoogleDriveSubfolderConfigDTO>()
		};
		VL_GoogleDriveConfigDTO cfg = new VL_GoogleDriveConfigDTO();
		cfg.isActive = true;
		cfg.rootFolderId = 'root1';
		cfg.sharedDriveId = null;
		cfg.enabledObjects = new List<String>{ 'account' };
		cfg.maxRetries = maxRetries;
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

	private static VL_TransferRequest buildRequest(ContentVersion cv, Id parentId) {
		return new VL_TransferRequest(
			parentId,
			'Account',
			'Queueable Test Account',
			cv.ContentDocumentId,
			cv.Id,
			'TestDoc.pdf',
			'application/pdf'
		);
	}

	private static VL_ExternalFile__c insertPendingRecord(VL_TransferRequest req) {
		VL_ExternalFile__c rec = new VL_ExternalFile__c(
			VL_ParentRecordId__c = String.valueOf(req.parentRecordId),
			VL_ParentObjectApiName__c = req.parentObjectApiName,
			VL_ContentDocumentId__c = req.contentDocumentId,
			VL_ContentVersionId__c = req.contentVersionId,
			VL_LogicalKey__c = req.logicalKey,
			VL_Status__c = 'Pending',
			VL_RetryCountNumber__c = 0
		);
		insert rec;
		return rec;
	}

	/**
	 * @name: happyPathTransitionsPendingToCompleted
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a successful transfer transitions the record from Pending to Completed.
	 */
	@IsTest
	static void happyPathTransitionsPendingToCompleted() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildConfig(3);
			Account acc = [SELECT Id FROM Account WHERE Name = 'Queueable Test Account' LIMIT 1];
			ContentVersion cv = insertContentVersion();
			VL_TransferRequest req = buildRequest(cv, acc.Id);
			insertPendingRecord(req);

			Test.setMock(
				HttpCalloutMock.class,
				new VL_UploadQueueableMultiMock(
					new List<String>{
						'{"files":[{"id":"objFolder1"}]}',
						'{"files":[{"id":"recFolder1"}]}',
						'{"id":"uploadedFile1","webViewLink":"https://drive.google.com/file/d/1/view"}'
					}
				)
			);

			Test.startTest();
			System.enqueueJob(new VL_GoogleDriveUploadQueueable(new List<VL_TransferRequest>{ req }));
			Test.stopTest();

			VL_ExternalFile__c updated = [
				SELECT VL_Status__c, VL_RemoteFileId__c, VL_RemoteLinkUrl__c, VL_LastErrorTxtArea__c
				FROM VL_ExternalFile__c
				WHERE VL_LogicalKey__c = :req.logicalKey
				LIMIT 1
			];
			System.assertEquals(
				'Completed',
				updated.VL_Status__c,
				'Status should be Completed after success: ' + updated.VL_LastErrorTxtArea__c
			);
			System.assertEquals('uploadedFile1', updated.VL_RemoteFileId__c, 'Remote file Id should be stored');
		}
	}

	/**
	 * @name: terminalErrorTransitionsToErrorImmediately
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a terminal auth error moves the record to Error without retry.
	 */
	@IsTest
	static void terminalErrorTransitionsToErrorImmediately() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildConfig(3);
			Account acc = [SELECT Id FROM Account WHERE Name = 'Queueable Test Account' LIMIT 1];
			ContentVersion cv = insertContentVersion();
			VL_TransferRequest req = buildRequest(cv, acc.Id);
			insertPendingRecord(req);

			Test.setMock(
				HttpCalloutMock.class,
				new VL_UploadQueueableMultiMock(
					new List<String>{ '{"files":[{"id":"objFolder1"}]}', '{"files":[{"id":"recFolder1"}]}', '{"error":"unauthorized"}' },
					new List<Integer>{ 200, 200, 200, 401 }
				)
			);

			Test.startTest();
			System.enqueueJob(new VL_GoogleDriveUploadQueueable(new List<VL_TransferRequest>{ req }));
			Test.stopTest();

			VL_ExternalFile__c updated = [
				SELECT VL_Status__c, VL_RetryCountNumber__c
				FROM VL_ExternalFile__c
				WHERE VL_LogicalKey__c = :req.logicalKey
				LIMIT 1
			];
			System.assertEquals('Error', updated.VL_Status__c, 'Terminal error should set status to Error');
			System.assertEquals(0, (Integer) updated.VL_RetryCountNumber__c, 'Retry count should remain 0 for terminal errors');
		}
	}

	/**
	 * @name: idempotencySkipsAlreadyCompletedRequests
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that re-queuing a completed transfer key results in no-op.
	 */
	@IsTest
	static void idempotencySkipsAlreadyCompletedRequests() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildConfig(3);
			Account acc = [SELECT Id FROM Account WHERE Name = 'Queueable Test Account' LIMIT 1];
			ContentVersion cv = insertContentVersion();
			VL_TransferRequest req = buildRequest(cv, acc.Id);
			// Insert as Completed to simulate idempotency
			VL_ExternalFile__c existing = new VL_ExternalFile__c(
				VL_ParentRecordId__c = String.valueOf(acc.Id),
				VL_ParentObjectApiName__c = 'Account',
				VL_ContentDocumentId__c = req.contentDocumentId,
				VL_ContentVersionId__c = req.contentVersionId,
				VL_LogicalKey__c = req.logicalKey,
				VL_Status__c = 'Completed',
				VL_RemoteFileId__c = 'existingFile',
				VL_RetryCountNumber__c = 0
			);
			insert existing;

			Test.setMock(HttpCalloutMock.class, new VL_UploadQueueableNoCallMock());

			Test.startTest();
			System.enqueueJob(new VL_GoogleDriveUploadQueueable(new List<VL_TransferRequest>{ req }));
			Test.stopTest();

			VL_ExternalFile__c after = [SELECT VL_Status__c, VL_RemoteFileId__c FROM VL_ExternalFile__c WHERE Id = :existing.Id];
			System.assertEquals('Completed', after.VL_Status__c, 'Completed record should remain Completed');
			System.assertEquals('existingFile', after.VL_RemoteFileId__c, 'Remote file Id should not be overwritten');
		}
	}

	/**
	 * @name: recoverableErrorBelowBudgetIncrementsRetry
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a recoverable error below the retry budget increments the retry count.
	 */
	@IsTest
	static void recoverableErrorBelowBudgetIncrementsRetry() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildConfig(3);
			Account acc = [SELECT Id FROM Account WHERE Name = 'Queueable Test Account' LIMIT 1];
			ContentVersion cv = insertContentVersion();
			VL_TransferRequest req = buildRequest(cv, acc.Id);
			insertPendingRecord(req);

			Test.setMock(
				HttpCalloutMock.class,
				new VL_UploadQueueableMultiMock(
					new List<String>{ '{"files":[{"id":"objFolder1"}]}', '{"files":[{"id":"recFolder1"}]}', '{"error":"rate limit"}' },
					new List<Integer>{ 200, 200, 200, 429 }
				)
			);

			VL_GoogleDriveUploadQueueable.suppressRequeue = true;
			new VL_GoogleDriveUploadQueueable(new List<VL_TransferRequest>{ req }).execute(null);

			VL_ExternalFile__c updated = [
				SELECT VL_RetryCountNumber__c, VL_Status__c
				FROM VL_ExternalFile__c
				WHERE VL_LogicalKey__c = :req.logicalKey
				LIMIT 1
			];
			System.assertEquals(1, (Integer) updated.VL_RetryCountNumber__c, 'Retry count should be incremented');
		}
	}

	/**
	 * @name: retryBudgetExhaustedSetsError
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that when retry count equals max retries, the record transitions to Error.
	 */
	@IsTest
	static void retryBudgetExhaustedSetsError() {
		User testUser = VL_TestDataFactory.getGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildConfig(3);
			Account acc = [SELECT Id FROM Account WHERE Name = 'Queueable Test Account' LIMIT 1];
			ContentVersion cv = insertContentVersion();
			VL_TransferRequest req = buildRequest(cv, acc.Id);
			insertPendingRecord(req);

			Test.setMock(
				HttpCalloutMock.class,
				new VL_UploadQueueableMultiMock(
					new List<String>{ '{"files":[{"id":"objFolder1"}]}', '{"files":[{"id":"recFolder1"}]}', '{"error":"rate limit"}' },
					new List<Integer>{ 200, 200, 200, 429 }
				)
			);

			// Pass retryCount = maxRetries to simulate exhausted budget
			Test.startTest();
			System.enqueueJob(new VL_GoogleDriveUploadQueueable(new List<VL_TransferRequest>{ req }, 3));
			Test.stopTest();

			VL_ExternalFile__c updated = [SELECT VL_Status__c FROM VL_ExternalFile__c WHERE VL_LogicalKey__c = :req.logicalKey LIMIT 1];
			System.assertEquals('Error', updated.VL_Status__c, 'Exhausted retry budget should set status to Error');
		}
	}

	// ── Mock helpers ─────────────────────────────────────────────────────────────

	/**
	 * @name VL_UploadQueueableMultiMock
	 * @version 1.0
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Sequential mock returning responses from a list.
	 */
	private class VL_UploadQueueableMultiMock implements HttpCalloutMock {
		private List<String> bodies;
		private List<Integer> statuses;
		private Integer idx = 0;

		public VL_UploadQueueableMultiMock(List<String> bodies) {
			this.bodies = bodies;
			this.statuses = new List<Integer>();
			for (String b : bodies) {
				statuses.add(200);
			}
		}

		public VL_UploadQueueableMultiMock(List<String> bodies, List<Integer> statuses) {
			this.bodies = bodies;
			this.statuses = statuses;
		}

		public HttpResponse respond(HttpRequest req) {
			HttpResponse resp = new HttpResponse();
			Integer responseIndex = idx;
			Integer responseStatus = responseIndex < statuses.size() ? statuses[responseIndex] : 200;
			idx++;
			Boolean isSuccessfulInitiation =
				req.getMethod() == 'POST' &&
				req.getHeader('X-Upload-Content-Type') != null &&
				responseStatus >= 200 &&
				responseStatus < 300;
			if (isSuccessfulInitiation) {
				resp.setStatusCode(200);
				resp.setHeader('Location', 'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&upload_id=test');
				resp.setBody('{}');
				return resp;
			}
			resp.setStatusCode(responseStatus);
			resp.setBody(responseIndex < bodies.size() ? bodies[responseIndex] : bodies[bodies.size() - 1]);
			return resp;
		}
	}

	/**
	 * @name VL_UploadQueueableNoCallMock
	 * @version 1.0
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Mock that fails if called — used to assert no callout is made.
	 */
	private class VL_UploadQueueableNoCallMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			System.assert(false, 'No callout should be made for idempotent requests');
			return null;
		}
	}
}