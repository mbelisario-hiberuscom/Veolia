/**
 * @name: VL_GenericListViewSelectorControllerTest
 * @creation date: 12/08/2026
 * @author: Jesus Piriz
 * @description Unit tests for generic list view retrieval, field metadata, values and user preferences.
 */
@IsTest
private class VL_GenericListViewSelectorControllerTest {
	private static final String OBJECT_API_NAME = 'Account';
	private static final String LIST_VIEW_API_NAME = 'AllAccounts';

	/**
	 * @name: setupData
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Creates the account and custom datatable configuration shared by all tests.
	 */
	@TestSetup
	static void setupData() {
		User testUser = VL_TestDataFactory.createGoogleDriveTestUser();
		System.runAs(testUser) {
			VL_TestDataFactory.createAccount('Generic Selector Test Account', null);

			VL_GenericDatatableType__c configuration = new VL_GenericDatatableType__c(
				VL_ObjectApiNameTxt__c = OBJECT_API_NAME,
				VL_FieldApiNameTxt__c = 'Name',
				VL_CustomDataTypeSel__c = 'PicklistColor'
			);
			insert configuration;
			insert new VL_GenericDatatableColor__c(
				VL_GenericDatatableTypeMDetail__c = configuration.Id,
				VL_ValueTxt__c = 'Generic Selector Test Account',
				VL_ColorSel__c = 'green'
			);
		}
	}

	/**
	 * @name: getListViewsReturnsEmptyForInvalidObjectAndDataForAccount
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies list view retrieval for invalid and valid object API names.
	 */
	@IsTest
	static void getListViewsReturnsEmptyForInvalidObjectAndDataForAccount() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			List<VL_GenericListViewSelectorController.ListViewData> invalidResult = VL_GenericListViewSelectorController.getListViews(
				'InvalidObject__c'
			);
			List<VL_GenericListViewSelectorController.ListViewData> accountResult = VL_GenericListViewSelectorController.getListViews(
				OBJECT_API_NAME
			);
			Test.stopTest();

			System.assertEquals(0, invalidResult.size(), 'Invalid objects should return no list views.');
			System.assertNotEquals(null, accountResult, 'A valid object should return a list.');
		}
	}

	/**
	 * @name: getFieldsReturnsAccessibleFieldsAndCustomType
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies accessible field metadata and configured custom datatable types.
	 */
	@IsTest
	static void getFieldsReturnsAccessibleFieldsAndCustomType() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			List<VL_GenericListViewSelectorController.FieldData> invalidResult = VL_GenericListViewSelectorController.getFields(
				'InvalidObject__c'
			);
			List<VL_GenericListViewSelectorController.FieldData> accountResult = VL_GenericListViewSelectorController.getFields(
				OBJECT_API_NAME
			);
			Test.stopTest();

			System.assertEquals(0, invalidResult.size(), 'Invalid objects should return no fields.');
			System.assert(accountResult.size() > 0, 'Account should expose accessible fields.');

			VL_GenericListViewSelectorController.FieldData nameField;
			for (VL_GenericListViewSelectorController.FieldData field : accountResult) {
				if (field.fieldApiName.equalsIgnoreCase('Name')) {
					nameField = field;
					break;
				}
			}
			System.assertNotEquals(null, nameField, 'The Account Name field should be returned.');
			System.assertEquals('PicklistColor', nameField.customDataType, 'The configured custom type should be returned.');
			System.assertEquals(
				'green',
				nameField.colorByValue.get('Generic Selector Test Account'),
				'The configured color should be returned.'
			);
		}
	}

	/**
	 * @name: getFieldValuesReturnsFieldsAndLookupLabels
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies scalar values, lookup labels and lookup IDs returned for records.
	 */
	@IsTest
	static void getFieldValuesReturnsFieldsAndLookupLabels() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Account accountRecord = [SELECT Id, Name, OwnerId FROM Account WHERE Name = 'Generic Selector Test Account' LIMIT 1];

			Test.startTest();
			List<VL_GenericListViewSelectorController.FieldValues> invalidObject = VL_GenericListViewSelectorController.getFieldValues(
				'InvalidObject__c',
				new List<String>{ accountRecord.Id },
				new List<String>{ 'Name' }
			);
			List<VL_GenericListViewSelectorController.FieldValues> invalidIds = VL_GenericListViewSelectorController.getFieldValues(
				OBJECT_API_NAME,
				new List<String>{ 'not-an-id' },
				new List<String>{ 'Name' }
			);
			List<VL_GenericListViewSelectorController.FieldValues> onlyId = VL_GenericListViewSelectorController.getFieldValues(
				OBJECT_API_NAME,
				new List<String>{ accountRecord.Id },
				new List<String>{ 'Id', 'VL_DefinitelyUnknownField999__c' }
			);
			List<VL_GenericListViewSelectorController.FieldValues> result = VL_GenericListViewSelectorController.getFieldValues(
				OBJECT_API_NAME,
				new List<String>{ accountRecord.Id },
				new List<String>{ 'Name', 'OwnerId', 'VL_DefinitelyUnknownField999__c' }
			);
			Test.stopTest();

			System.assertEquals(0, invalidObject.size(), 'Invalid objects should return no values.');
			System.assertEquals(0, invalidIds.size(), 'Invalid record IDs should be ignored.');
			System.assertEquals(1, onlyId.size(), 'A valid record ID should return the record even without additional valid fields.');
			System.assertEquals(0, onlyId[0].values.size(), 'No additional values should be returned for invalid fields.');
			System.assertEquals(1, result.size(), 'One record should be returned.');
			System.assertEquals(accountRecord.Id, result[0].recordId, 'The returned record ID should match the requested record.');
			Object returnedName = result[0].values.get('Name');
			if (returnedName == null) {
				returnedName = result[0].values.get('name');
			}
			System.assertEquals(accountRecord.Name, returnedName, 'The scalar field value should be returned.');
			Object returnedOwnerName = result[0].values.get('OwnerId');
			if (returnedOwnerName == null) {
				returnedOwnerName = result[0].values.get('ownerid');
			}
			System.assertEquals(UserInfo.getName(), returnedOwnerName, 'The lookup label should be returned.');
			Object returnedOwnerId = result[0].values.get('OwnerId__url');
			if (returnedOwnerId == null) {
				returnedOwnerId = result[0].values.get('ownerid__url');
			}
			System.assertEquals(accountRecord.OwnerId, returnedOwnerId, 'The lookup ID should be returned for navigation.');
		}
	}

	/**
	 * @name: settingsCanBeSavedAndLoadedPerUser
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies selected list view, column configuration and page size persistence.
	 */
	@IsTest
	static void settingsCanBeSavedAndLoadedPerUser() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			VL_GenericListViewSelectorController.ListViewSettings emptySettings = VL_GenericListViewSelectorController.getSettings(
				OBJECT_API_NAME
			);
			VL_GenericListViewSelectorController.saveSettings(OBJECT_API_NAME, LIST_VIEW_API_NAME, LIST_VIEW_API_NAME + '~v2:name', 999);
			VL_GenericListViewSelectorController.ListViewSettings savedSettings = VL_GenericListViewSelectorController.getSettings(
				OBJECT_API_NAME
			);
			Test.stopTest();

			System.assertEquals(null, emptySettings.selectedListViewApiName, 'No preference should exist before saving.');
			System.assertEquals(LIST_VIEW_API_NAME, savedSettings.selectedListViewApiName, 'The selected list view should be persisted.');
			System.assertEquals(20, savedSettings.pageSize, 'Invalid page sizes should use the default value.');
			System.assertEquals(
				LIST_VIEW_API_NAME + '~v2:name',
				savedSettings.columnConfiguration,
				'The column configuration should be serialized for the selected list view.'
			);

			VL_UserListViewPreference__c preference = [
				SELECT Id, VL_PageSizeNum__c, VL_IsSelected__c
				FROM VL_UserListViewPreference__c
				WHERE VL_UserLookup__c = :UserInfo.getUserId() AND VL_ObjectApiNameTxt__c = :OBJECT_API_NAME
				LIMIT 1
			];
			System.assertEquals(20, preference.VL_PageSizeNum__c, 'The default page size should be stored.');
			System.assertEquals(true, preference.VL_IsSelected__c, 'The saved list view should be selected.');

			List<SObject> columns = Database.query(
				'SELECT VL_FieldApiNameTxt__c, VL_PositionNum__c, VL_IsVisible__c ' +
					'FROM VL_UserListViewPreferenceColumn__c ' +
					'WHERE VL_UserListViewPreferenceMDetail__c = \'' +
					String.escapeSingleQuotes(String.valueOf(preference.Id)) +
					'\' ' +
					'ORDER BY VL_PositionNum__c'
			);
			System.assertEquals(1, columns.size(), 'Only selected columns should be persisted.');
			System.assertEquals(
				'name',
				((String) columns[0].get('VL_FieldApiNameTxt__c')).toLowerCase(),
				'The first column should retain its position.'
			);
			System.assertEquals(true, (Boolean) columns[0].get('VL_IsVisible__c'), 'Name should remain visible.');

			preference.VL_PageSizeNum__c = null;
			update preference;
			VL_GenericListViewSelectorController.ListViewSettings defaultPageSettings = VL_GenericListViewSelectorController.getSettings(
				OBJECT_API_NAME
			);
			System.assertEquals(20, defaultPageSettings.pageSize, 'A missing stored page size should use the default value.');

			VL_GenericListViewSelectorController.saveSettings(OBJECT_API_NAME, LIST_VIEW_API_NAME, LIST_VIEW_API_NAME + '~v2:name', 50);

			VL_GenericListViewSelectorController.ListViewSettings updatedSettings = VL_GenericListViewSelectorController.getSettings(
				OBJECT_API_NAME
			);
			System.assertEquals(50, updatedSettings.pageSize, 'A valid page size should be persisted.');
			System.assertEquals(
				LIST_VIEW_API_NAME + '~v2:name',
				updatedSettings.columnConfiguration,
				'The updated configuration should replace the old one.'
			);
			System.assertEquals(
				1,
				[SELECT COUNT() FROM VL_UserListViewPreferenceColumn__c WHERE VL_UserListViewPreferenceMDetail__c = :preference.Id],
				'Updating settings should replace the existing columns.'
			);
		}
	}

	/**
	 * @name: getSettingsReturnsEmptyForInvalidObject
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that invalid object API names return empty settings safely.
	 */
	@IsTest
	static void getSettingsReturnsEmptyForInvalidObject() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			VL_GenericListViewSelectorController.ListViewSettings result = VL_GenericListViewSelectorController.getSettings(
				'InvalidObject__c'
			);
			Test.stopTest();

			System.assertEquals(null, result.selectedListViewApiName, 'Invalid objects should not have a selected list view.');
			System.assertEquals(null, result.columnConfiguration, 'Invalid objects should not have column settings.');
			System.assertEquals(null, result.pageSize, 'Invalid objects should not have a page size.');
		}
	}

	/**
	 * @name: getFieldValuesReturnsEmptyForMissingInputs
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that missing record or field inputs return an empty result without querying.
	 */
	@IsTest
	static void getFieldValuesReturnsEmptyForMissingInputs() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			List<VL_GenericListViewSelectorController.FieldValues> missingRecords = VL_GenericListViewSelectorController.getFieldValues(
				OBJECT_API_NAME,
				new List<String>(),
				new List<String>{ 'Name' }
			);
			List<VL_GenericListViewSelectorController.FieldValues> missingFields = VL_GenericListViewSelectorController.getFieldValues(
				OBJECT_API_NAME,
				new List<String>{ UserInfo.getUserId() },
				new List<String>()
			);
			Test.stopTest();

			System.assertEquals(0, missingRecords.size(), 'Missing record IDs should return no values.');
			System.assertEquals(0, missingFields.size(), 'Missing field names should return no values.');
		}
	}
}