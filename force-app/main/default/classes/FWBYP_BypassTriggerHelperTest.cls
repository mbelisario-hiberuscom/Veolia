/**
 * @name FWBYP_BypassTriggerHelperTest
 * @version 1.1
 * @creation date: 03/11/2025
 * @author: Jesus Piriz
 * @description Test class to test FWBYP_BypassTriggerHelper functionality
 * @last_update: 17/04/2026 - Added tests for fieldExistsInSetting and getAvailableBypassFields methods
 **/
@IsTest
public with sharing class FWBYP_BypassTriggerHelperTest {
	/**
	 * @name: initialSetup
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Method to create the necessary data for this test.
	 */
	@testSetup
	static void initialSetup() {
		FWBYP_Settings__c recordSetting = new FWBYP_Settings__c();
		recordSetting.Name = 'Test';
		recordSetting.FWBYP_AllTriggers__c = true;
		recordSetting.SetupOwnerId = UserInfo.getProfileId();
		insert recordSetting;
	}

	/**
	 * @name: checkBypassTest
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Method to check checkBypass method
	 */
	@IsTest
	public static void checkBypassTest() {
		Test.startTest();
		Boolean checkpass = FWBYP_BypassTriggerHelper.checkBypass('FWBYP_AllTriggers__c', UserInfo.getUserId());
		Test.stopTest();

		System.assertEquals(true, checkpass);
	}

	/**
	 * @name: checkBypassNoExistFieldTest
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Method to check checkBypass method with a field that dont exist
	 */
	@IsTest
	public static void checkBypassNoExistFieldTest() {
		FWBYP_Settings__c cs = [SELECT Id FROM FWBYP_Settings__c LIMIT 1];
		cs.FWBYP_AllTriggers__c = false;
		update cs;

		Test.startTest();
		Boolean checkpass = FWBYP_BypassTriggerHelper.checkBypass('FWBYP_AccountTrigger__c', UserInfo.getUserId());
		Test.stopTest();

		System.assertEquals(false, checkpass);
	}

	/**
	 * @name: checkBypassWithoutValueTest
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Method to check checkBypass method
	 */
	@IsTest
	public static void checkBypassWithoutValueTest() {
		Test.startTest();
		Boolean checkpass = FWBYP_BypassTriggerHelper.checkBypass('', UserInfo.getUserId());
		Test.stopTest();

		System.assertEquals(true, checkpass);
	}

	/**
	 * @name: fieldExistsInSettingTest
	 * @creation date: 17/04/2026
	 * @author: Jesus Piriz
	 * @description Method to test fieldExistsInSetting method with existing field
	 */
	@IsTest
	public static void fieldExistsInSettingTest() {
		Test.startTest();
		Boolean fieldExists = FWBYP_BypassTriggerHelper.fieldExistsInSetting('FWBYP_AllTriggers__c');
		Test.stopTest();

		System.assertEquals(true, fieldExists, 'FWBYP_AllTriggers__c field should exist');
	}

	/**
	 * @name: fieldExistsInSettingNonExistentTest
	 * @creation date: 17/04/2026
	 * @author: Jesus Piriz
	 * @description Method to test fieldExistsInSetting method with non-existent field
	 */
	@IsTest
	public static void fieldExistsInSettingNonExistentTest() {
		Test.startTest();
		Boolean fieldExists = FWBYP_BypassTriggerHelper.fieldExistsInSetting('FWBYP_NonExistentField__c');
		Test.stopTest();

		System.assertEquals(false, fieldExists, 'Non-existent field should not exist');
	}

	/**
	 * @name: fieldExistsInSettingBlankTest
	 * @creation date: 17/04/2026
	 * @author: Jesus Piriz
	 * @description Method to test fieldExistsInSetting method with blank field name
	 */
	@IsTest
	public static void fieldExistsInSettingBlankTest() {
		Test.startTest();
		Boolean fieldExists = FWBYP_BypassTriggerHelper.fieldExistsInSetting('');
		Test.stopTest();

		System.assertEquals(false, fieldExists, 'Blank field name should return false');
	}

	/**
	 * @name: getAvailableBypassFieldsTest
	 * @creation date: 17/04/2026
	 * @author: Jesus Piriz
	 * @description Method to test getAvailableBypassFields method
	 */
	@IsTest
	public static void getAvailableBypassFieldsTest() {
		Test.startTest();
		List<String> availableFields = FWBYP_BypassTriggerHelper.getAvailableBypassFields();
		Test.stopTest();

		System.assertNotEquals(null, availableFields, 'Available fields list should not be null');
		System.assert(availableFields.size() >= 3, 'Should have at least 3 FWBYP_ bypass fields');
	}

	/**
	 * @name: checkBypassWithGlobalBypassEnabledTest
	 * @creation date: 17/04/2026
	 * @author: Jesus Piriz
	 * @description Method to check that global bypass applies to any field when enabled
	 */
	@IsTest
	public static void checkBypassWithGlobalBypassEnabledTest() {
		Test.startTest();
		Boolean checkpass = FWBYP_BypassTriggerHelper.checkBypass('FWBYP_AllFlows__c', UserInfo.getUserId());
		Test.stopTest();

		System.assertEquals(true, checkpass, 'Should return true when global FWBYP_AllTriggers__c is enabled');
	}

	/**
	 * @name: checkBypassWithSpecificFieldDisabledTest
	 * @creation date: 17/04/2026
	 * @author: Jesus Piriz
	 * @description Method to check bypass when specific field is disabled
	 */
	@IsTest
	public static void checkBypassWithSpecificFieldDisabledTest() {
		FWBYP_Settings__c cs = [SELECT Id FROM FWBYP_Settings__c LIMIT 1];
		cs.FWBYP_AllTriggers__c = false;
		cs.FWBYP_AllFlows__c = false;
		update cs;

		Test.startTest();
		Boolean checkpass = FWBYP_BypassTriggerHelper.checkBypass('FWBYP_AllFlows__c', UserInfo.getUserId());
		Test.stopTest();

		System.assertEquals(false, checkpass, 'Should return false when specific field is disabled');
	}

	/**
	 * @name: checkBypassWithSpecificFieldEnabledTest
	 * @creation date: 17/04/2026
	 * @author: Jesus Piriz
	 * @description Method to check bypass when specific field is enabled
	 */
	@IsTest
	public static void checkBypassWithSpecificFieldEnabledTest() {
		FWBYP_Settings__c cs = [SELECT Id FROM FWBYP_Settings__c LIMIT 1];
		cs.FWBYP_AllTriggers__c = false;
		cs.FWBYP_AllFlows__c = true;
		update cs;

		Test.startTest();
		Boolean checkpass = FWBYP_BypassTriggerHelper.checkBypass('FWBYP_AllFlows__c', UserInfo.getUserId());
		Test.stopTest();

		System.assertEquals(true, checkpass, 'Should return true when specific field is enabled');
	}
}