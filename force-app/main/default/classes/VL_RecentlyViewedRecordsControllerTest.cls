/**
 * @name VL_RecentlyViewedRecordsControllerTest
 * @version 1.0
 * @creation date 13/08/2026
 * @author Jesus Piriz
 * @description Tests for VL_RecentlyViewedRecordsController.
 */
@IsTest
private with sharing class VL_RecentlyViewedRecordsControllerTest {
	/**
	 * @name setupData
	 * @creation date: 13/08/2026
	 * @author: Jesus Piriz
	 * @description Creates records available to the test methods.
	 */
	@TestSetup
	static void setupData() {
		User testUser = VL_TestDataFactory.createGoogleDriveTestUser();
		System.runAs(testUser) {
			String runKey = String.valueOf(Crypto.getRandomLong()).replace('-', '');
			VL_TestDataFactory.createAccount('Recently Viewed ' + runKey, null);
		}
	}

	/**
	 * @name getRecentlyViewedRecordsReturnsRecords
	 * @creation date: 13/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies the generic controller returns the configured object records.
	 */
	@IsTest
	static void getRecentlyViewedRecordsReturnsRecords() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Account account = [SELECT Id, Name FROM Account LIMIT 1];
			// FOR VIEW registers the record as recently viewed so LastViewedDate is populated.
			List<Account> viewed = [SELECT Id FROM Account WHERE Id = :account.Id FOR VIEW];
			System.assertEquals(1, viewed.size(), 'The account should be marked as recently viewed.');

			Test.startTest();
			List<VL_RecentlyViewedRecordsController.RecentlyViewedRecord> result = VL_RecentlyViewedRecordsController.getRecentlyViewedRecords(
				'Account',
				5
			);
			Test.stopTest();

			System.assertNotEquals(null, result, 'The result should be initialized.');
			System.assertEquals(false, result.isEmpty(), 'The recently viewed account should be returned.');
			System.assertEquals(account.Id, result[0].recordId, 'The viewed account Id should be returned.');
			System.assertEquals('Account', result[0].objectApiName, 'The object API name should be returned.');
			System.assertEquals(account.Name, result[0].recordName, 'The account name should be returned as display name.');
		}
	}

	/**
	 * @name getRecentlyViewedRecordsRejectsInvalidObject
	 * @creation date: 13/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies invalid object names are rejected before dynamic SOQL execution.
	 */
	@IsTest
	static void getRecentlyViewedRecordsRejectsInvalidObject() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			try {
				VL_RecentlyViewedRecordsController.getRecentlyViewedRecords('InvalidObject__c', 5);
				System.assert(false, 'An invalid object should raise an AuraHandledException.');
			} catch (Exception exceptionValue) {
				System.assert(exceptionValue instanceof AuraHandledException, 'An invalid object should raise an AuraHandledException.');
			}
		}
	}

	/**
	 * @name getRecentlyViewedRecordsRejectsBlankObject
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies a blank object API name is rejected before any describe or query runs.
	 */
	@IsTest
	static void getRecentlyViewedRecordsRejectsBlankObject() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			try {
				VL_RecentlyViewedRecordsController.getRecentlyViewedRecords('', 5);
				System.assert(false, 'A blank object API name should raise an AuraHandledException.');
			} catch (Exception exceptionValue) {
				System.assert(exceptionValue instanceof AuraHandledException, 'A blank object API name should raise an AuraHandledException.');
			}
		}
	}

	/**
	 * @name getRecentlyViewedRecordsUsesDefaultLimitWhenNull
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies a null record limit falls back to the default size without failing.
	 */
	@IsTest
	static void getRecentlyViewedRecordsUsesDefaultLimitWhenNull() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			List<VL_RecentlyViewedRecordsController.RecentlyViewedRecord> result = VL_RecentlyViewedRecordsController.getRecentlyViewedRecords(
				'Account',
				null
			);
			Test.stopTest();

			System.assertNotEquals(null, result, 'The result should be initialized when the limit is null.');
		}
	}
}