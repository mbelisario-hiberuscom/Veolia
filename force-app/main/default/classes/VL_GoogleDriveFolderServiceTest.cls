/**
 * @name VL_GoogleDriveFolderServiceTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_GoogleDriveFolderService folder search and creation logic.
 **/
@IsTest
private class VL_GoogleDriveFolderServiceTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	private static final String MOCK_FOLDER_ID = 'folderABC123';
	private static final String ROOT_ID = 'rootFolder1';
	private static final String SHARED_DRIVE_ID = 'sharedDrive1';

	/**
	 * @name: ensureRecordFolderReusesStoredId
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that when a stored folder Id is provided, no search callout is made.
	 */
	@IsTest
	static void ensureRecordFolderReusesStoredId() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveFolderService service = new VL_GoogleDriveFolderService(new VL_GoogleDriveHttpClient());

			Test.startTest();
			String folderId = service.ensureRecordFolder(MOCK_FOLDER_ID, 'TestRecord', 'recordFolder1', null);
			Test.stopTest();

			System.assertEquals('recordFolder1', folderId, 'Stored folder Id should be returned without callout');
		}
	}

	/**
	 * @name: ensureConfiguredSubfoldersSearchesAndCreatesConfiguredFolders
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that configured subfolders are reused when present and created when absent.
	 */
	@IsTest
	static void ensureConfiguredSubfoldersSearchesAndCreatesConfiguredFolders() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveSubfolderConfigSelector.cachedByObject = new Map<String, List<VL_GoogleDriveSubfolderConfigDTO>>{
				'lead' => new List<VL_GoogleDriveSubfolderConfigDTO>{
					new VL_GoogleDriveSubfolderConfigDTO('Lead', 'Documentacion', 1, true),
					new VL_GoogleDriveSubfolderConfigDTO('Lead', 'Oferta', 2, true)
				}
			};
			Test.setMock(
				HttpCalloutMock.class,
				new VL_GoogleDriveFolderServiceMock(
					new List<String>{ '{"files":[{"id":"existingDocumentation"}]}', '{"files":[]}', '{"id":"newOffer"}' }
				)
			);
			VL_GoogleDriveFolderService service = new VL_GoogleDriveFolderService(new VL_GoogleDriveHttpClient());

			Test.startTest();
			List<String> folderIds = service.ensureConfiguredSubfolders('Lead', 'recordFolder1', SHARED_DRIVE_ID);
			Test.stopTest();

			System.assertEquals(2, folderIds.size(), 'All active configured subfolders should be returned');
			System.assertEquals('existingDocumentation', folderIds[0], 'Existing configured folder should be reused');
			System.assertEquals('newOffer', folderIds[1], 'Missing configured folder should be created');
		}
	}

	/**
	 * @name: ensureObjectFolderSearchesAndCreatesWhenAbsent
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that when no folder exists, a search returns empty and a create call is made.
	 */
	@IsTest
	static void ensureObjectFolderSearchesAndCreatesWhenAbsent() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(
				HttpCalloutMock.class,
				new VL_GoogleDriveFolderServiceMock(new List<String>{ '{"files":[]}', '{"id":"newFolder99"}' })
			);
			VL_GoogleDriveFolderService service = new VL_GoogleDriveFolderService(new VL_GoogleDriveHttpClient());

			Test.startTest();
			String folderId = service.ensureObjectFolder('Opportunity', ROOT_ID, null);
			Test.stopTest();

			System.assertEquals('newFolder99', folderId, 'Newly created folder Id should be returned');
		}
	}

	/**
	 * @name: ensureObjectFolderReusesExistingFolder
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that when a folder already exists in Drive, its Id is returned without creating.
	 */
	@IsTest
	static void ensureObjectFolderReusesExistingFolder() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(
				HttpCalloutMock.class,
				new VL_GoogleDriveFolderServiceMock(new List<String>{ '{"files":[{"id":"existingFolder77"}]}' })
			);
			VL_GoogleDriveFolderService service = new VL_GoogleDriveFolderService(new VL_GoogleDriveHttpClient());

			Test.startTest();
			String folderId = service.ensureObjectFolder('Lead', ROOT_ID, null);
			Test.stopTest();

			System.assertEquals('existingFolder77', folderId, 'Existing folder Id should be returned without creating a new one');
		}
	}

	/**
	 * @name: ensureObjectFolderPassesSupportsAllDrives
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that the search query includes supportsAllDrives=true parameter.
	 */
	@IsTest
	static void ensureObjectFolderPassesSupportsAllDrives() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveFolderServiceCapturingMock mock = new VL_GoogleDriveFolderServiceCapturingMock('{"files":[{"id":"folder1"}]}');
			Test.setMock(HttpCalloutMock.class, mock);
			VL_GoogleDriveFolderService service = new VL_GoogleDriveFolderService(new VL_GoogleDriveHttpClient());

			Test.startTest();
			service.ensureObjectFolder('Account', ROOT_ID, null);
			Test.stopTest();

			System.assert(mock.capturedEndpoint.contains('supportsAllDrives=true'), 'Request should include supportsAllDrives=true');
		}
	}

	/**
	 * @name: ensureObjectFolderPropagatesTerminalError
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a terminal API error surfaces as VL_GoogleDriveException.
	 */
	@IsTest
	static void ensureObjectFolderPropagatesTerminalError() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveFolderServiceMock(new List<String>{ '{"error":"forbidden"}', '401' }));
			VL_GoogleDriveFolderService service = new VL_GoogleDriveFolderService(new VL_GoogleDriveHttpClient());

			Boolean exceptionThrown = false;
			Test.startTest();
			try {
				VL_GoogleDriveFolderServiceMock mockAuth = new VL_GoogleDriveFolderServiceMock(new List<String>());
				Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(401, '{"error":"unauthorized"}'));
				service.ensureObjectFolder('Quote', ROOT_ID, null);
			} catch (VL_GoogleDriveException ex) {
				exceptionThrown = true;
			}
			Test.stopTest();

			System.assertEquals(true, exceptionThrown, 'Terminal API error should propagate as VL_GoogleDriveException');
		}
	}

	// ── Mock helpers ────────────────────────────────────────────────────────────

	/**
	 * @name VL_GoogleDriveFolderServiceMock
	 * @version 1.0
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Multi-response mock returning each body in sequence.
	 */
	public class VL_GoogleDriveFolderServiceMock implements HttpCalloutMock {
		private List<String> responses;
		private Integer callCount = 0;

		public VL_GoogleDriveFolderServiceMock(List<String> responses) {
			this.responses = responses;
		}

		public HttpResponse respond(HttpRequest req) {
			HttpResponse resp = new HttpResponse();
			if (callCount < responses.size()) {
				resp.setStatusCode(200);
				resp.setBody(responses[callCount++]);
			} else {
				resp.setStatusCode(200);
				resp.setBody('{}');
			}
			return resp;
		}
	}

	/**
	 * @name VL_GoogleDriveFolderServiceCapturingMock
	 * @version 1.0
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Mock that captures the endpoint for assertion.
	 */
	public class VL_GoogleDriveFolderServiceCapturingMock implements HttpCalloutMock {
		private String responseBody;
		public String capturedEndpoint;

		public VL_GoogleDriveFolderServiceCapturingMock(String responseBody) {
			this.responseBody = responseBody;
		}

		public HttpResponse respond(HttpRequest req) {
			capturedEndpoint = req.getEndpoint();
			HttpResponse resp = new HttpResponse();
			resp.setStatusCode(200);
			resp.setBody(responseBody);
			return resp;
		}
	}
}