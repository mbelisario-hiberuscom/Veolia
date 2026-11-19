/**
 * @name VL_GenericRelatedListControllerTest
 * @version 1.0
 * @creation date: 13/08/2026
 * @author: Jesus Piriz
 * @description Tests for the reusable generic related list controller.
 **/
@IsTest
private class VL_GenericRelatedListControllerTest {
	@TestSetup
	static void setupData() {
		User testUser = VL_TestDataFactory.createGoogleDriveTestUser();
		System.runAs(testUser) {
			String runKey = String.valueOf(Crypto.getRandomLong()).replace('-', '');
			Account account = VL_TestDataFactory.createAccount('Related List Account ' + runKey, null);
			VL_TestDataFactory.createContact('First Contact', account, 'first@example.com');
			VL_TestDataFactory.createContact('Second Contact', account, 'second@example.com');
		}
	}

	/**
	 * @name getRelatedRecordsReturnsAccessibleFields
	 * @creation date: 13/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies related records and lookup display values are returned.
	 */
	@IsTest
	static void getRelatedRecordsReturnsAccessibleFields() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			mockFieldSet();
			Account account = [SELECT Id FROM Account WHERE Name LIKE '%Related List Account%' LIMIT 1];

			Test.startTest();
			VL_GenericRelatedListController.RelatedListResponse response = VL_GenericRelatedListController.getRelatedRecords(
				account.Id,
				'Contact',
				'VL_TestRelatedList',
				'AccountId = :recordId AND Email LIKE \'%@example.com\'',
				'LastName ASC',
				1
			);
			Test.stopTest();

			System.assertEquals(1, response.records.size(), 'The query limit should be applied');
			System.assertEquals(3, response.fields.size(), 'The field set fields should be returned');
		}
	}

	/**
	 * @name getRelatedRecordsRejectsInvalidRelationship
	 * @creation date: 13/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies invalid relationship configuration returns no records.
	 */
	@IsTest
	static void getRelatedRecordsRejectsInvalidRelationship() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			mockFieldSet();
			Account account = [SELECT Id FROM Account WHERE Name LIKE '%Related List Account%' LIMIT 1];

			Test.startTest();
			VL_GenericRelatedListController.RelatedListResponse response = VL_GenericRelatedListController.getRelatedRecords(
				account.Id,
				'Contact',
				'VL_TestRelatedList',
				'AccountId = :recordId AND LastName = \'Missing\'',
				null,
				20
			);
			Test.stopTest();

			System.assertEquals(0, response.records.size(), 'A non-reference relationship field must be rejected');
		}
	}

	private static void mockFieldSet() {
		VL_GenericRelatedListController.fieldSetFieldsByName = new Map<String, List<String>>{
			'VL_TestRelatedList' => new List<String>{ 'LastName', 'Email', 'AccountId' }
		};
	}
}