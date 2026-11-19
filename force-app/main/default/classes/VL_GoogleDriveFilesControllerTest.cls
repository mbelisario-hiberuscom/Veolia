/**
 * @name VL_GoogleDriveFilesControllerTest
 * @version 2.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_GoogleDriveFilesController live Drive explorer: folder resolution,
 *              child listing, and null/blank input handling. Drive callouts are mocked.
 */
@IsTest
private class VL_GoogleDriveFilesControllerTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	private static final String SEARCH_BODY = '{"files":[{"id":"OBJFOLDER","name":"Account"}]}';
	private static final String LIST_BODY =
		'{"files":[' +
		'{"id":"SUB1","name":"Subfolder","mimeType":"application/vnd.google-apps.folder"},' +
		'{"id":"FILE1","name":"Report.pdf","mimeType":"application/pdf","size":"2097152",' +
		'"modifiedTime":"2026-08-31T10:00:00.000Z","webViewLink":"https://drive.google.com/file/d/FILE1/view"}' +
		']}';

	private static final Id ACCOUNT_ID = '001000000000001AAA';
	private static final String EMPTY_LIST_BODY = '{"files":[]}';

	private static void primeConfig() {
		VL_GoogleDriveConfigDTO config = new VL_GoogleDriveConfigDTO();
		config.rootFolderId = 'ROOTFOLDER';
		config.sharedDriveId = null;
		config.folderNamingPattern = '{RecordId}-{RecordName}';
		config.isActive = true;
		config.enabledObjects = new List<String>();
		config.maxRetries = 3;
		config.autoCleanup = false;
		config.maxFileSizeMb = 25;
		VL_GoogleDriveConfigSelector.cachedConfig = config;
	}

	/**
	 * @name: getMaxFileSizeMbReturnsConfiguredValue
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that the active CMT file-size limit is exposed to the LWC.
	 */
	@IsTest
	static void getMaxFileSizeMbReturnsConfiguredValue() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			VL_GoogleDriveConfigSelector.cachedConfig.maxFileSizeMb = 10.5;

			Test.startTest();
			Decimal result = VL_GoogleDriveFilesController.getMaxFileSizeMb();
			Test.stopTest();

			System.assertEquals(10.5, result, 'The configured decimal file-size limit should be returned.');
		}
	}

	/**
	 * @name: getRootFolderResolvesFolder
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Resolves a record to its live Drive folder when object and record folders exist.
	 */
	@IsTest
	static void getRootFolderResolvesFolder() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(200, SEARCH_BODY));

			Test.startTest();
			VL_DriveFolderDTO result = VL_GoogleDriveFilesController.getRootFolder(ACCOUNT_ID);
			Test.stopTest();

			System.assertNotEquals(null, result, 'A folder DTO should be returned');
			System.assertEquals('OBJFOLDER', result.folderId, 'Record folder Id should come from the search response');
			System.assert(result.folderName.contains(String.valueOf(ACCOUNT_ID)), 'Folder name should include the record Id');
		}
	}

	/**
	 * @name: getRootFolderReturnsNullFolderIdWhenMissing
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description When the object folder does not exist, folderId is null but the folder name is still provided.
	 */
	@IsTest
	static void getRootFolderReturnsNullFolderIdWhenMissing() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(200, '{"files":[]}'));

			Test.startTest();
			VL_DriveFolderDTO result = VL_GoogleDriveFilesController.getRootFolder(ACCOUNT_ID);
			Test.stopTest();

			System.assertEquals(null, result.folderId, 'folderId should be null when no object folder exists');
			System.assert(String.isNotBlank(result.folderName), 'Folder name should still be built');
		}
	}

	/**
	 * @name: getRootFolderReturnsNullForNullId
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Null recordId returns null without performing a callout.
	 */
	@IsTest
	static void getRootFolderReturnsNullForNullId() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			VL_DriveFolderDTO result = VL_GoogleDriveFilesController.getRootFolder(null);
			Test.stopTest();

			System.assertEquals(null, result, 'Null recordId should return null');
		}
	}

	/**
	 * @name: ensureRecordFolderReturnsNullForNullId
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Null recordId returns null without attempting to resolve a folder.
	 */
	@IsTest
	static void ensureRecordFolderReturnsNullForNullId() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			VL_DriveFolderDTO result = VL_GoogleDriveFilesController.ensureRecordFolder(null);
			Test.stopTest();

			System.assertEquals(null, result, 'Null recordId should return null');
		}
	}

	/**
	 * @name: getExternalFileStatusesReturnsTraceabilityStatus
	 * @creation date: 03/09/2026
	 * @author: Jesus Piriz
	 * @description Returns the status of a traceability record belonging to the requested parent record.
	 */
	@IsTest
	static void getExternalFileStatusesReturnsTraceabilityStatus() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Account account = VL_TestDataFactory.createAccount('Controller Status Account', null);
			VL_TransferRequest request = new VL_TransferRequest(
				account.Id,
				'Account',
				account.Name,
				'controller-doc',
				'controller-version',
				'controller.pdf',
				'application/pdf'
			);
			VL_ExternalFile__c traceabilityRecord = VL_ExternalFileService.createPendingRecords(new List<VL_TransferRequest>{ request })[0];

			Test.startTest();
			List<VL_ExternalFileStatusDTO> result = VL_GoogleDriveFilesController.getExternalFileStatuses(
				account.Id,
				new List<Id>{ traceabilityRecord.Id }
			);
			Test.stopTest();

			System.assertEquals(1, result.size(), 'One traceability status should be returned');
			System.assertEquals('Pending', result[0].status, 'The pending status should be returned');
		}
	}

	/**
	 * @name: ensureRecordFolderCreatesHierarchy
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Creates the object, record, and configured subfolder hierarchy from a Salesforce record Id.
	 */
	@IsTest
	static void ensureRecordFolderCreatesHierarchy() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			VL_GoogleDriveConfigSelector.cachedConfig.enabledObjects = new List<String>{ 'account' };
			VL_GoogleDriveSubfolderConfigSelector.cachedByObject = new Map<String, List<VL_GoogleDriveSubfolderConfigDTO>>{
				'account' => new List<VL_GoogleDriveSubfolderConfigDTO>{ new VL_GoogleDriveSubfolderConfigDTO('Account', 'Contracts', 1, true) }
			};
			Account account = VL_TestDataFactory.createAccount('Folder Creation Account', null);
			Test.setMock(
				HttpCalloutMock.class,
				new SequenceDriveMock(
					new List<String>{
						'{"files":[]}',
						'{"id":"OBJECT_CREATED"}',
						'{"files":[]}',
						'{"id":"RECORD_CREATED"}',
						'{"files":[]}',
						'{"id":"SUBFOLDER_CREATED"}'
					}
				)
			);

			Test.startTest();
			VL_DriveFolderDTO result = VL_GoogleDriveFilesController.ensureRecordFolder(account.Id);
			Test.stopTest();

			System.assertEquals('RECORD_CREATED', result.folderId, 'The record folder Id should be returned');
			System.assert(result.folderName.contains(String.valueOf(account.Id)), 'The record folder name should include the record Id');
		}
	}

	/**
	 * @name: listFolderReturnsChildren
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Lists children of a folder, mapping folders and files with parsed size.
	 */
	@IsTest
	static void listFolderReturnsChildren() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(200, LIST_BODY));

			Test.startTest();
			List<VL_DriveItemDTO> items = VL_GoogleDriveFilesController.listFolder('OBJFOLDER');
			Test.stopTest();

			System.assertEquals(2, items.size(), 'Both children should be returned');
			System.assertEquals(true, items[0].isFolder, 'First entry should be a folder');
			System.assertEquals(false, items[1].isFolder, 'Second entry should be a file');
			System.assertEquals(2097152L, items[1].sizeBytes, 'File size should be parsed from the size string');
			System.assertEquals('https://drive.google.com/file/d/FILE1/view', items[1].webViewLink, 'Web view link should be mapped');
		}
	}

	/**
	 * @name: listFolderAddsConvertedLeadFolder
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Adds one read-only virtual folder for a converted Lead using the Lead's real Drive folder Id.
	 */
	@IsTest
	static void listFolderAddsConvertedLeadFolder() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			Account account = VL_TestDataFactory.createAccount('Converted Lead Account', null);
			Opportunity opportunity = VL_TestDataFactory.createOpportunity('Converted Lead Opportunity', account);
			Lead lead = VL_TestDataFactory.createLead('Original', 'Lead One', 'Converted Company', 'lead.one@test.com');
			setConvertedLeadNamesForTest(new List<Lead>{ lead });
			Test.setMock(
				HttpCalloutMock.class,
				new SequenceDriveMock(
					new List<String>{
						EMPTY_LIST_BODY,
						'{"files":[{"id":"OPP_OBJECT"}]}',
						'{"files":[{"id":"OPP_RECORD"}]}',
						'{"files":[{"id":"LEAD_OBJECT"}]}',
						'{"files":[{"id":"LEAD_RECORD"}]}'
					}
				)
			);

			Test.startTest();
			List<VL_DriveItemDTO> items = VL_GoogleDriveFilesController.listFolder('OPP_RECORD', opportunity.Id);
			Test.stopTest();

			System.assertEquals(1, items.size(), 'One converted Lead should produce one virtual folder');
			System.assertEquals('LEAD_RECORD', items[0].id, 'Virtual folder should use the existing Lead Drive folder Id');
			System.assertEquals(true, items[0].isFolder, 'Converted Lead entry should be rendered as a folder');
			System.assertEquals(true, items[0].isLinkedFolder, 'Converted Lead entry should be marked as linked');
			System.assertEquals(true, items[0].isReadOnly, 'Converted Lead entry should be read-only');
			Lead queriedLead = [SELECT Name FROM Lead WHERE Id = :lead.Id];
			System.assert(items[0].name.contains(queriedLead.Name), 'Virtual folder name should identify the original Lead');
		}
	}

	/**
	 * @name: listFolderAddsOneFolderPerConvertedLead
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Adds one independent virtual folder for every converted Lead related to the Opportunity.
	 */
	@IsTest
	static void listFolderAddsOneFolderPerConvertedLead() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			Account account = VL_TestDataFactory.createAccount('Multiple Converted Leads Account', null);
			Opportunity opportunity = VL_TestDataFactory.createOpportunity('Multiple Converted Leads Opportunity', account);
			Lead firstLead = VL_TestDataFactory.createLead('First', 'Converted', 'Converted Company', 'first.converted@test.com');
			Lead secondLead = VL_TestDataFactory.createLead('Second', 'Converted', 'Converted Company', 'second.converted@test.com');
			setConvertedLeadNamesForTest(new List<Lead>{ firstLead, secondLead });
			Test.setMock(
				HttpCalloutMock.class,
				new SequenceDriveMock(
					new List<String>{
						EMPTY_LIST_BODY,
						'{"files":[{"id":"OPP_OBJECT"}]}',
						'{"files":[{"id":"OPP_RECORD"}]}',
						'{"files":[{"id":"LEAD_OBJECT"}]}',
						'{"files":[{"id":"FIRST_RECORD"}]}',
						'{"files":[{"id":"SECOND_RECORD"}]}'
					}
				)
			);

			Test.startTest();
			List<VL_DriveItemDTO> items = VL_GoogleDriveFilesController.listFolder('OPP_RECORD', opportunity.Id);
			Test.stopTest();

			System.assertEquals(2, items.size(), 'Each converted Lead should produce one virtual folder');
			System.assertEquals('FIRST_RECORD', items[0].id, 'Converted Leads should be ordered by Lead name');
			System.assertEquals('SECOND_RECORD', items[1].id, 'Both converted Lead folders should be returned');
		}
	}

	/**
	 * @name: listFolderWithoutConvertedLeadsReturnsDriveItems
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Returns the real Drive children without linked folders when the Opportunity has no converted Leads.
	 */
	@IsTest
	static void listFolderWithoutConvertedLeadsReturnsDriveItems() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			Account account = VL_TestDataFactory.createAccount('No Converted Leads Account', null);
			Opportunity opportunity = VL_TestDataFactory.createOpportunity('No Converted Leads Opportunity', account);
			Test.setMock(
				HttpCalloutMock.class,
				new SequenceDriveMock(new List<String>{ LIST_BODY, '{"files":[{"id":"OPP_OBJECT"}]}', '{"files":[{"id":"OPP_RECORD"}]}' })
			);

			Test.startTest();
			List<VL_DriveItemDTO> items = VL_GoogleDriveFilesController.listFolder('OPP_RECORD', opportunity.Id);
			Test.stopTest();

			System.assertEquals(2, items.size(), 'Real Drive children should remain visible');
			System.assertEquals(false, items[0].isLinkedFolder, 'Real Drive folders should not be marked as linked');
		}
	}

	/**
	 * @name: listFolderDoesNotInjectOutsideOpportunityRoot
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Does not inject converted Lead folders when the requested Drive folder is not the Opportunity root.
	 */
	@IsTest
	static void listFolderDoesNotInjectOutsideOpportunityRoot() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			Account account = VL_TestDataFactory.createAccount('Arbitrary Folder Account', null);
			Opportunity opportunity = VL_TestDataFactory.createOpportunity('Arbitrary Folder Opportunity', account);
			Lead lead = VL_TestDataFactory.createLead('Arbitrary', 'Lead', 'Converted Company', 'arbitrary.lead@test.com');
			setConvertedLeadNamesForTest(new List<Lead>{ lead });
			Test.setMock(
				HttpCalloutMock.class,
				new SequenceDriveMock(new List<String>{ EMPTY_LIST_BODY, '{"files":[{"id":"OPP_OBJECT"}]}', '{"files":[{"id":"OPP_RECORD"}]}' })
			);

			Test.startTest();
			List<VL_DriveItemDTO> items = VL_GoogleDriveFilesController.listFolder('ARBITRARY_FOLDER', opportunity.Id);
			Test.stopTest();

			System.assertEquals(0, items.size(), 'An arbitrary folder must not receive virtual Lead folders');
		}
	}

	/**
	 * @name: listFolderOmitsConvertedLeadWithoutDriveFolder
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Omits a converted Lead when its Drive record folder does not exist.
	 */
	@IsTest
	static void listFolderOmitsConvertedLeadWithoutDriveFolder() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			Account account = VL_TestDataFactory.createAccount('Missing Lead Folder Account', null);
			Opportunity opportunity = VL_TestDataFactory.createOpportunity('Missing Lead Folder Opportunity', account);
			Lead lead = VL_TestDataFactory.createLead('Missing', 'Folder', 'Converted Company', 'missing.folder@test.com');
			setConvertedLeadNamesForTest(new List<Lead>{ lead });
			Test.setMock(
				HttpCalloutMock.class,
				new SequenceDriveMock(
					new List<String>{
						EMPTY_LIST_BODY,
						'{"files":[{"id":"OPP_OBJECT"}]}',
						'{"files":[{"id":"OPP_RECORD"}]}',
						'{"files":[{"id":"LEAD_OBJECT"}]}',
						EMPTY_LIST_BODY
					}
				)
			);

			Test.startTest();
			List<VL_DriveItemDTO> items = VL_GoogleDriveFilesController.listFolder('OPP_RECORD', opportunity.Id);
			Test.stopTest();

			System.assertEquals(0, items.size(), 'A converted Lead without a Drive folder should be omitted');
		}
	}

	/**
	 * @name: listFolderReturnsEmptyForBlank
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Blank folderId returns an empty list without a callout.
	 */
	@IsTest
	static void listFolderReturnsEmptyForBlank() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			List<VL_DriveItemDTO> items = VL_GoogleDriveFilesController.listFolder('');
			Test.stopTest();

			System.assertEquals(0, items.size(), 'Blank folderId should return an empty list');
		}
	}

	/**
	 * @name: listFolderWrapsDriveFailure
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description A non-2xx Drive response is wrapped as an AuraHandledException for the LWC.
	 */
	@IsTest
	static void listFolderWrapsDriveFailure() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			primeConfig();
			Test.setMock(HttpCalloutMock.class, new VL_GoogleDriveHttpMock(500, '{"error":"server"}'));

			Boolean thrown = false;
			Test.startTest();
			try {
				VL_GoogleDriveFilesController.listFolder('OBJFOLDER');
			} catch (AuraHandledException ex) {
				thrown = true;
			}
			Test.stopTest();

			System.assertEquals(true, thrown, 'A Drive failure should surface as AuraHandledException');
		}
	}

	/**
	 * @name: getRootFolderWrapsConfigFailure
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description A missing active configuration surfaces as an AuraHandledException.
	 */
	@IsTest
	static void getRootFolderWrapsConfigFailure() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfigSelector.noActiveRecordForTest = true;

			Boolean thrown = false;
			Test.startTest();
			try {
				VL_GoogleDriveFilesController.getRootFolder(ACCOUNT_ID);
			} catch (AuraHandledException ex) {
				thrown = true;
			}
			Test.stopTest();

			System.assertEquals(true, thrown, 'Missing configuration should surface as AuraHandledException');
		}
	}

	/**
	 * @name: getMaxFileSizeMbWrapsConfigFailure
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description A missing active configuration surfaces from getMaxFileSizeMb as an AuraHandledException.
	 */
	@IsTest
	static void getMaxFileSizeMbWrapsConfigFailure() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfigSelector.cachedConfig = null;
			VL_GoogleDriveConfigSelector.noActiveRecordForTest = true;

			Boolean thrown = false;
			Test.startTest();
			try {
				VL_GoogleDriveFilesController.getMaxFileSizeMb();
			} catch (AuraHandledException ex) {
				thrown = true;
			}
			Test.stopTest();

			System.assertEquals(true, thrown, 'Missing configuration should surface as AuraHandledException');
		}
	}

	/**
	 * @name: ensureRecordFolderWrapsConfigFailure
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description A missing active configuration surfaces from ensureRecordFolder as an AuraHandledException.
	 */
	@IsTest
	static void ensureRecordFolderWrapsConfigFailure() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Account account = VL_TestDataFactory.createAccount('Ensure Folder Failure Account', null);
			VL_GoogleDriveConfigSelector.cachedConfig = null;
			VL_GoogleDriveConfigSelector.noActiveRecordForTest = true;

			Boolean thrown = false;
			Test.startTest();
			try {
				VL_GoogleDriveFilesController.ensureRecordFolder(account.Id);
			} catch (AuraHandledException ex) {
				thrown = true;
			}
			Test.stopTest();

			System.assertEquals(true, thrown, 'Missing configuration should surface as AuraHandledException');
		}
	}

	/**
	 * @name: getExternalFileStatusesReturnsEmptyForNullInputs
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Null or empty inputs return an empty status list without querying traceability records.
	 */
	@IsTest
	static void getExternalFileStatusesReturnsEmptyForNullInputs() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			List<VL_ExternalFileStatusDTO> nullRecord = VL_GoogleDriveFilesController.getExternalFileStatuses(null, new List<Id>());
			List<VL_ExternalFileStatusDTO> emptyIds = VL_GoogleDriveFilesController.getExternalFileStatuses(ACCOUNT_ID, new List<Id>());
			Test.stopTest();

			System.assertEquals(0, nullRecord.size(), 'A null record Id should return an empty list');
			System.assertEquals(0, emptyIds.size(), 'An empty Id list should return an empty list');
		}
	}

	private static void setConvertedLeadNamesForTest(List<Lead> leads) {
		VL_GoogleDriveExplorerService.convertedLeadNamesByIdForTest = new Map<Id, String>();
		for (Lead lead : [SELECT Id, Name FROM Lead WHERE Id IN :leads]) {
			VL_GoogleDriveExplorerService.convertedLeadNamesByIdForTest.put(lead.Id, lead.Name);
		}
	}

	/**
	 * @name SequenceDriveMock
	 * @version 1.0
	 * @creation date: 02/09/2026
	 * @author: Jesus Piriz
	 * @description Returns deterministic Google Drive responses in request order.
	 */
	private class SequenceDriveMock implements HttpCalloutMock {
		private List<String> responses;
		private Integer callIndex = 0;

		/**
		 * @name SequenceDriveMock
		 * @creation date: 02/09/2026
		 * @author: Jesus Piriz
		 * @description Creates a mock with ordered response bodies.
		 * @param responses Response bodies returned for successive requests.
		 */
		public SequenceDriveMock(List<String> responses) {
			this.responses = responses;
		}

		/**
		 * @name respond
		 * @creation date: 02/09/2026
		 * @author: Jesus Piriz
		 * @description Returns the next configured Drive response.
		 * @param request HTTP request received from the code under test.
		 * @return HttpResponse mocked Drive response.
		 */
		public HttpResponse respond(HttpRequest request) {
			HttpResponse response = new HttpResponse();
			response.setStatusCode(200);
			response.setBody(callIndex < responses.size() ? responses[callIndex++] : EMPTY_LIST_BODY);
			return response;
		}
	}
}