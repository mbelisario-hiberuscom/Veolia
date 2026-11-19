/**
 * @name VL_GoogleDriveConfigSelectorTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_GoogleDriveConfigSelector config loading, caching, and object-enabled logic.
 **/
@IsTest
private class VL_GoogleDriveConfigSelectorTest {
	@TestSetup
	static void setupData() {
		VL_TestDataFactory.createGoogleDriveTestUser();
	}

	private static VL_GoogleDriveConfigDTO buildActiveConfig() {
		VL_GoogleDriveConfigDTO cfg = new VL_GoogleDriveConfigDTO();
		cfg.isActive = true;
		cfg.rootFolderId = 'rootFolder123';
		cfg.sharedDriveId = null;
		cfg.enabledObjects = new List<String>{ 'lead', 'account', 'opportunity', 'quote' };
		cfg.maxRetries = 3;
		cfg.autoCleanup = false;
		cfg.folderNamingPattern = '{RecordId}-{RecordName}';
		cfg.maxFileSizeMb = 25;
		return cfg;
	}

	/**
	 * @name: getActiveReturnsCachedConfig
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that getActive returns the injected test config and caches it for subsequent calls.
	 */
	@IsTest
	static void getActiveReturnsCachedConfig() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfigSelector.cachedConfig = buildActiveConfig();

			Test.startTest();
			VL_GoogleDriveConfigDTO first = VL_GoogleDriveConfigSelector.getActive();
			VL_GoogleDriveConfigDTO second = VL_GoogleDriveConfigSelector.getActive();
			Test.stopTest();

			System.assertNotEquals(null, first, 'Config should not be null');
			System.assertEquals('rootFolder123', first.rootFolderId, 'Root folder Id should match injected value');
			System.assert(first === second, 'Repeated calls should return the same cached instance');
		}
	}

	/**
	 * @name: mapToDtoMapsMetadataFields
	 * @creation date: 01/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies that Custom Metadata fields are mapped into the configuration DTO.
	 */
	@IsTest
	static void mapToDtoMapsMetadataFields() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfiguration__mdt metadata = new VL_GoogleDriveConfiguration__mdt(
				VL_RootFolderIdTxt__c = 'metadataRoot',
				VL_SharedDriveIdTxt__c = 'metadataDrive',
				VL_EnabledObjectsTxtArea__c = ' Lead , Account ',
				VL_MaxRetriesNumber__c = 5,
				VL_HasAutoCleanup__c = true,
				VL_FolderNamingPatternTxt__c = '{RecordName}',
				VL_IsActive__c = true,
				VL_MaxFileSizeMbNumber__c = 10.5
			);

			Test.startTest();
			VL_GoogleDriveConfigDTO config = VL_GoogleDriveConfigSelector.mapToDto(metadata);
			Test.stopTest();

			System.assertEquals('metadataRoot', config.rootFolderId, 'Root folder should be mapped');
			System.assertEquals('metadataDrive', config.sharedDriveId, 'Shared drive should be mapped');
			System.assertEquals(5, config.maxRetries, 'Retry limit should be mapped');
			System.assertEquals(true, config.autoCleanup, 'Auto cleanup should be mapped');
			System.assertEquals('{RecordName}', config.folderNamingPattern, 'Folder pattern should be mapped');
			System.assertEquals(true, config.isActive, 'Mapped configuration should be active');
			System.assertEquals(10.5, config.maxFileSizeMb, 'Maximum file size should preserve one decimal place');
			System.assertEquals(new List<String>{ 'lead', 'account' }, config.enabledObjects, 'Enabled objects should be normalized');
		}
	}

	/**
	 * @name: parseEnabledObjectsTrimsAndLowercases
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that enabled objects CSV is parsed trimming whitespace and converting to lowercase.
	 */
	@IsTest
	static void parseEnabledObjectsTrimsAndLowercases() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfigDTO cfg = buildActiveConfig();
			cfg.enabledObjects = VL_GoogleDriveConfigSelector.parseEnabledObjectsCsv(' Lead , Account , Opportunity , Quote ');
			VL_GoogleDriveConfigSelector.cachedConfig = cfg;

			Test.startTest();
			Boolean leadEnabled = VL_GoogleDriveConfigSelector.isObjectEnabled('Lead');
			Boolean accountEnabled = VL_GoogleDriveConfigSelector.isObjectEnabled('ACCOUNT');
			Boolean contactEnabled = VL_GoogleDriveConfigSelector.isObjectEnabled('Contact');
			Test.stopTest();

			System.assertEquals(true, leadEnabled, 'Lead should be enabled (case-insensitive)');
			System.assertEquals(true, accountEnabled, 'Account should be enabled (case-insensitive)');
			System.assertEquals(false, contactEnabled, 'Contact should not be enabled');
		}
	}

	/**
	 * @name: isObjectEnabledReturnsFalseWhenInactive
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that isObjectEnabled returns false when the config is inactive.
	 */
	@IsTest
	static void isObjectEnabledReturnsFalseWhenInactive() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfigDTO cfg = buildActiveConfig();
			cfg.isActive = false;
			VL_GoogleDriveConfigSelector.cachedConfig = cfg;

			Test.startTest();
			Boolean result = VL_GoogleDriveConfigSelector.isObjectEnabled('Opportunity');
			Test.stopTest();

			System.assertEquals(false, result, 'Object should not be enabled when config is inactive');
		}
	}

	/**
	 * @name: getActiveThrowsWhenNoActiveRecord
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that getActive throws VL_GoogleDriveException TERMINAL_CONFIG when no active record exists.
	 */
	@IsTest
	static void getActiveThrowsWhenNoActiveRecord() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfigSelector.cachedConfig = null;
			VL_GoogleDriveConfigSelector.noActiveRecordForTest = true;

			Boolean exceptionThrown = false;
			VL_GoogleDriveException.ErrorCategory errorCategory;

			Test.startTest();
			try {
				VL_GoogleDriveConfigSelector.getActive();
			} catch (VL_GoogleDriveException ex) {
				exceptionThrown = true;
				errorCategory = ex.getCategory();
			}
			Test.stopTest();

			System.assertEquals(true, exceptionThrown, 'Exception should be thrown when no active config record exists');
			System.assertEquals(
				VL_GoogleDriveException.ErrorCategory.TERMINAL_CONFIG,
				errorCategory,
				'Exception category should be TERMINAL_CONFIG'
			);
		}
	}

	/**
	 * @name: getActiveReadsActiveMetadataRecord
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies getActive queries and maps the active Custom Metadata record when nothing is cached.
	 */
	@IsTest
	static void getActiveReadsActiveMetadataRecord() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfigSelector.cachedConfig = null;
			VL_GoogleDriveConfigSelector.noActiveRecordForTest = false;

			Test.startTest();
			VL_GoogleDriveConfigDTO config = VL_GoogleDriveConfigSelector.getActive();
			Test.stopTest();

			System.assertNotEquals(null, config, 'The active metadata record should be read and mapped');
			System.assertEquals(true, config.isActive, 'The mapped configuration should be active');
		}
	}

	/**
	 * @name: isObjectEnabledReturnsFalseWhenConfigMissing
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies isObjectEnabled swallows the terminal-config exception and returns false.
	 */
	@IsTest
	static void isObjectEnabledReturnsFalseWhenConfigMissing() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfigSelector.cachedConfig = null;
			VL_GoogleDriveConfigSelector.noActiveRecordForTest = true;

			Test.startTest();
			Boolean result = VL_GoogleDriveConfigSelector.isObjectEnabled('Account');
			Test.stopTest();

			System.assertEquals(false, result, 'A missing configuration should make isObjectEnabled return false');
		}
	}

	/**
	 * @name: parseEnabledObjectsReturnsEmptyForBlank
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies a blank CSV returns an empty normalized list.
	 */
	@IsTest
	static void parseEnabledObjectsReturnsEmptyForBlank() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			List<String> result = VL_GoogleDriveConfigSelector.parseEnabledObjectsCsv('');
			Test.stopTest();

			System.assertEquals(true, result.isEmpty(), 'A blank CSV should return an empty list');
		}
	}

	/**
	 * @name: mapToDtoAppliesDefaultsForNullValues
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies mapToDto applies the retry, file-size and naming-pattern defaults when values are null.
	 */
	@IsTest
	static void mapToDtoAppliesDefaultsForNullValues() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_GoogleDriveConfiguration__mdt metadata = new VL_GoogleDriveConfiguration__mdt(
				VL_RootFolderIdTxt__c = 'root',
				VL_IsActive__c = true
			);

			Test.startTest();
			VL_GoogleDriveConfigDTO config = VL_GoogleDriveConfigSelector.mapToDto(metadata);
			Test.stopTest();

			System.assertEquals(3, config.maxRetries, 'Retry limit should default to 3 when null');
			System.assertEquals(25, config.maxFileSizeMb, 'File-size limit should default to 25 when null');
			System.assertEquals('{RecordId}-{RecordName}', config.folderNamingPattern, 'Naming pattern should use the default when blank');
			System.assertEquals(false, config.autoCleanup, 'Auto cleanup should default to false when null');
			System.assertEquals(true, config.enabledObjects.isEmpty(), 'Enabled objects should be empty when the CSV is blank');
		}
	}
}