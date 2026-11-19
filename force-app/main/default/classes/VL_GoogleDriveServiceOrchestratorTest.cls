/**
 * @name VL_GoogleDriveServiceOrchestratorTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_GoogleDriveServiceOrchestrator end-to-end orchestration.
 **/
@IsTest
private class VL_GoogleDriveServiceOrchestratorTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	private static VL_GoogleDriveConfigDTO buildConfig() {
		VL_GoogleDriveConfigDTO cfg = new VL_GoogleDriveConfigDTO();
		cfg.isActive = true;
		cfg.rootFolderId = 'root1';
		cfg.sharedDriveId = null;
		cfg.enabledObjects = new List<String>{ 'opportunity' };
		cfg.maxRetries = 3;
		cfg.autoCleanup = false;
		cfg.folderNamingPattern = '{RecordId}-{RecordName}';
		cfg.maxFileSizeMb = 25;
		return cfg;
	}

	private static VL_TransferRequest buildRequest() {
		return new VL_TransferRequest(
			'006000000000001AAA',
			'Opportunity',
			'Test Opportunity',
			'doc001',
			'ver001',
			'file.pdf',
			'application/pdf'
		);
	}

	/**
	 * @name: happyPathReturnsFolderIdAndRemoteFileId
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies the happy path: folder search returns existing, upload succeeds,
	 *              and the result carries remoteFileId, remoteFolderId, and webViewLink.
	 */
	@IsTest
	static void happyPathReturnsFolderIdAndRemoteFileId() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(
				HttpCalloutMock.class,
				new VL_OrchestratorMultiMock(
					new List<String>{
						'{"files":[{"id":"objFolder1"}]}',
						'{"files":[{"id":"recFolder1"}]}',
						'{"id":"uploadedFile1","webViewLink":"https://drive.google.com/file/d/1/view"}'
					}
				)
			);
			VL_GoogleDriveConfigDTO config = buildConfig();
			VL_TransferRequest req = buildRequest();
			ContentVersion cv = buildContentVersion();
			VL_GoogleDriveServiceOrchestrator orch = new VL_GoogleDriveServiceOrchestrator();

			Test.startTest();
			VL_GoogleDriveServiceOrchestrator.VL_OrchestratorResult result = orch.transfer(req, config, null, cv);
			Test.stopTest();

			System.assertEquals('uploadedFile1', result.remoteFileId, 'Remote file Id should match');
			System.assertEquals('recFolder1', result.remoteFolderId, 'Record folder Id should match');
			System.assertEquals('https://drive.google.com/file/d/1/view', result.webViewLink, 'Web view link should match');
		}
	}

	/**
	 * @name: requestedRecordFolderIsUsedAsDestination
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a folder selected in the LWC is used as the Drive upload destination.
	 */
	@IsTest
	static void requestedRecordFolderIsUsedAsDestination() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_OrchestratorMultiMock mock = new VL_OrchestratorMultiMock(
				new List<String>{
					'{"files":[{"id":"objFolder1"}]}',
					'{"files":[{"id":"recFolder1"}]}',
					'{"id":"uploadedFileRoot1","webViewLink":"https://drive.google.com/file/d/root/view"}'
				}
			);
			Test.setMock(HttpCalloutMock.class, mock);
			VL_GoogleDriveConfigDTO config = buildConfig();
			VL_TransferRequest req = buildRequest();
			req.requestedDriveFolderId = 'recFolder1';
			ContentVersion cv = buildContentVersion();
			VL_GoogleDriveServiceOrchestrator orch = new VL_GoogleDriveServiceOrchestrator();

			Test.startTest();
			orch.transfer(req, config, null, req.requestedDriveFolderId, cv);
			Test.stopTest();

			System.assert(mock.uploadMetadata.contains('recFolder1'), 'Upload should target the selected record folder');
		}
	}

	/**
	 * @name: requestedConfiguredSubfolderIsUsedAsDestination
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a configured subfolder selected in the LWC is accepted as the upload destination.
	 */
	@IsTest
	static void requestedConfiguredSubfolderIsUsedAsDestination() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveSubfolderConfigSelector.cachedByObject = new Map<String, List<VL_GoogleDriveSubfolderConfigDTO>>{
				'opportunity' => new List<VL_GoogleDriveSubfolderConfigDTO>{
					new VL_GoogleDriveSubfolderConfigDTO('Opportunity', 'Documentacion', 1, true)
				}
			};
			VL_OrchestratorMultiMock mock = new VL_OrchestratorMultiMock(
				new List<String>{
					'{"files":[{"id":"objFolder1"}]}',
					'{"files":[{"id":"recFolder1"}]}',
					'{"files":[{"id":"configuredFolder1"}]}',
					'{"id":"uploadedFileConfigured","webViewLink":"https://drive.google.com/file/d/configured/view"}'
				}
			);
			Test.setMock(HttpCalloutMock.class, mock);
			VL_GoogleDriveConfigDTO config = buildConfig();
			VL_TransferRequest req = buildRequest();
			req.requestedDriveFolderId = 'configuredFolder1';
			ContentVersion cv = buildContentVersion();
			VL_GoogleDriveServiceOrchestrator orch = new VL_GoogleDriveServiceOrchestrator();

			Test.startTest();
			orch.transfer(req, config, null, req.requestedDriveFolderId, cv);
			Test.stopTest();

			System.assert(mock.uploadMetadata.contains('configuredFolder1'), 'Upload should target the selected configured subfolder');
		}
	}

	/**
	 * @name: oversizedFileThrowsTerminalValidation
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a file exceeding the max size threshold throws TERMINAL_VALIDATION.
	 */
	@IsTest
	static void oversizedFileThrowsTerminalValidation() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfigDTO config = buildConfig();
			config.maxFileSizeMb = 0; // 0 MB max means everything is too large
			VL_TransferRequest req = buildRequest();
			ContentVersion cv = buildContentVersion();
			VL_GoogleDriveServiceOrchestrator orch = new VL_GoogleDriveServiceOrchestrator();

			Test.startTest();
			VL_GoogleDriveException caught = null;
			try {
				orch.transfer(req, config, null, cv);
			} catch (VL_GoogleDriveException ex) {
				caught = ex;
			}
			Test.stopTest();

			System.assertNotEquals(null, caught, 'Should throw for oversized file');
			System.assertEquals(
				VL_GoogleDriveException.ErrorCategory.TERMINAL_VALIDATION,
				caught.getCategory(),
				'Should be TERMINAL_VALIDATION'
			);
		}
	}

	/**
	 * @name: configuredSizeIsCappedAtSalesforceCalloutLimit
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that the effective upload limit uses decimal MB and never exceeds Salesforce's callout limit.
	 */
	@IsTest
	static void configuredSizeIsCappedAtSalesforceCalloutLimit() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			System.assertEquals(
				25000000,
				VL_GoogleDriveServiceOrchestrator.calculateMaxUploadBytes(25),
				'25 MB should map to the Salesforce callout limit'
			);
			System.assertEquals(
				25000000,
				VL_GoogleDriveServiceOrchestrator.calculateMaxUploadBytes(30),
				'Configured limits above 25 MB must be capped at the Salesforce callout limit'
			);
			System.assertEquals(
				10000000,
				VL_GoogleDriveServiceOrchestrator.calculateMaxUploadBytes(10),
				'Limits below 25 MB should use decimal MB conversion'
			);
			System.assertEquals(
				23500000,
				VL_GoogleDriveServiceOrchestrator.calculateMaxUploadBytes(23.5),
				'Decimal limits should preserve one decimal place'
			);
		}
	}

	/**
	 * @name: storedFolderIdSkipsFolderSearch
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that when storedFolderId is provided, record folder search is skipped.
	 */
	@IsTest
	static void storedFolderIdSkipsFolderSearch() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			// Two mocks: object folder search + upload.
			Test.setMock(
				HttpCalloutMock.class,
				new VL_OrchestratorMultiMock(
					new List<String>{
						'{"files":[{"id":"objFolder1"}]}',
						'{"id":"uploadedFile2","webViewLink":"https://drive.google.com/file/d/2/view"}'
					}
				)
			);
			VL_GoogleDriveConfigDTO config = buildConfig();
			VL_TransferRequest req = buildRequest();
			ContentVersion cv = buildContentVersion();
			VL_GoogleDriveServiceOrchestrator orch = new VL_GoogleDriveServiceOrchestrator();

			Test.startTest();
			VL_GoogleDriveServiceOrchestrator.VL_OrchestratorResult result = orch.transfer(req, config, 'storedFolder99', cv);
			Test.stopTest();

			System.assertEquals('storedFolder99', result.remoteFolderId, 'Stored folder Id should be reused');
		}
	}

	/**
	 * @name: uploadFailurePropagatesClassifiedException
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a non-2xx upload response surfaces as a VL_GoogleDriveException.
	 */
	@IsTest
	static void uploadFailurePropagatesClassifiedException() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(
				HttpCalloutMock.class,
				new VL_OrchestratorMultiMock(
					new List<String>{ '{"files":[{"id":"objFolder1"}]}', '{"files":[{"id":"recFolder1"}]}', '{"error":"unauthorized"}' },
					new List<Integer>{ 200, 200, 401 }
				)
			);
			VL_GoogleDriveConfigDTO config = buildConfig();
			VL_TransferRequest req = buildRequest();
			ContentVersion cv = buildContentVersion();
			VL_GoogleDriveServiceOrchestrator orch = new VL_GoogleDriveServiceOrchestrator();

			Test.startTest();
			VL_GoogleDriveException caught = null;
			try {
				orch.transfer(req, config, null, cv);
			} catch (VL_GoogleDriveException ex) {
				caught = ex;
			}
			Test.stopTest();

			System.assertNotEquals(null, caught, 'Should throw on upload failure');
			System.assertEquals(VL_GoogleDriveException.ErrorCategory.TERMINAL_AUTH, caught.getCategory(), 'Should be TERMINAL_AUTH for 401');
		}
	}

	// ── Helpers ──────────────────────────────────────────────────────────────────

	private static ContentVersion buildContentVersion() {
		ContentVersion cv = new ContentVersion(
			Title = 'file.pdf',
			PathOnClient = 'file.pdf',
			VersionData = Blob.valueOf('test content'),
			IsMajorVersion = true
		);
		return cv;
	}

	/**
	 * @name VL_OrchestratorMultiMock
	 * @version 1.0
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Mock that returns responses from a sequential list.
	 */
	private class VL_OrchestratorMultiMock implements HttpCalloutMock {
		private List<String> bodies;
		private List<Integer> statuses;
		private Integer callIndex = 0;
		private String uploadMetadata;

		public VL_OrchestratorMultiMock(List<String> bodies) {
			this.bodies = bodies;
			this.statuses = new List<Integer>();
			for (String b : bodies) {
				this.statuses.add(200);
			}
		}

		public VL_OrchestratorMultiMock(List<String> bodies, List<Integer> statuses) {
			this.bodies = bodies;
			this.statuses = statuses;
		}

		public HttpResponse respond(HttpRequest req) {
			HttpResponse resp = new HttpResponse();
			Boolean isSuccessfulInitiation =
				req.getMethod() == 'POST' &&
				req.getHeader('X-Upload-Content-Type') != null &&
				statuses[callIndex] >= 200 &&
				statuses[callIndex] < 300;
			if (isSuccessfulInitiation) {
				uploadMetadata = req.getBody();
				resp.setStatusCode(200);
				resp.setHeader('Location', 'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&upload_id=test');
				resp.setBody('{}');
				return resp;
			}
			resp.setStatusCode(statuses[callIndex]);
			resp.setBody(bodies[callIndex]);
			callIndex++;
			return resp;
		}
	}
}