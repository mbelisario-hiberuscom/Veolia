/**
 * @name VL_AccountDuplicateFinderTest
 * @version 1.0
 * @creation date: 02/09/2026
 * @author: Daniel Landete
 * @description Tests Account duplicate detection through Salesforce duplicate rules.
 */
@IsTest
private class VL_AccountDuplicateFinderTest {
	/**
	 * @name emptyRequestsReturnEmptyResults
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Verifies that an empty Flow invocation returns no results.
	 */
	@IsTest
	static void emptyRequestsReturnEmptyResults() {
		Test.startTest();
		List<VL_AccountDuplicateFinder.Response> results = VL_AccountDuplicateFinder.findNameDuplicates(null);
		Test.stopTest();

		System.assertEquals(0, results.size(), 'An empty request must return an empty result list.');
	}

	/**
	 * @name blankAccountNameReturnsNoDuplicate
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Verifies that an Account without a name is ignored safely.
	 */
	@IsTest
	static void blankAccountNameReturnsNoDuplicate() {
		VL_AccountDuplicateFinder.Request request = new VL_AccountDuplicateFinder.Request();
		request.account = new Account();

		Test.startTest();
		List<VL_AccountDuplicateFinder.Response> results = VL_AccountDuplicateFinder.findNameDuplicates(
			new List<VL_AccountDuplicateFinder.Request>{ request }
		);
		Test.stopTest();

		System.assertEquals(1, results.size(), 'One result must be returned for one request.');
		System.assertEquals(false, results[0].hasNameDuplicate, 'A blank Account name cannot match a duplicate.');
	}

	/**
	 * @name matchingAccountNameReturnsDuplicate
	 * @creation date: 02/09/2026
	 * @author: Daniel Landete
	 * @description Verifies that the active Account name duplicate rule detects a matching name.
	 */
	@IsTest
	static void matchingAccountNameReturnsDuplicate() {
		Account existingAccount = VL_TestDataFactory.createAccount('Acme Industrial', null);
		existingAccount.VL_Active__c = true;
		update existingAccount;

		VL_AccountDuplicateFinder.Request request = new VL_AccountDuplicateFinder.Request();
		request.account = new Account(Name = 'Acme Industrial', VL_Active__c = true);

		Test.startTest();
		List<VL_AccountDuplicateFinder.Response> results = VL_AccountDuplicateFinder.findNameDuplicates(
			new List<VL_AccountDuplicateFinder.Request>{ request }
		);
		Test.stopTest();

		System.assertEquals(1, results.size(), 'One result must be returned for one request.');
		System.assertEquals(true, results[0].hasNameDuplicate, 'The active name duplicate rule must detect the Account.');
		System.assertEquals(existingAccount.Name, results[0].duplicateAccountName, 'The matched Account name must be returned.');
	}
}