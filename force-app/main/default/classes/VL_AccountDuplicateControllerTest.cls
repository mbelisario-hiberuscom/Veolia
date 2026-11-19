/**
 * @name: VL_AccountDuplicateControllerTest
 * @version: 1.0
 * @creation date: 01/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Tests for Account duplicate candidate searches.
 */
@IsTest
private with sharing class VL_AccountDuplicateControllerTest {
	/**
	 * @name: findsFiscalAndNameCandidatesExcludingCurrentAccount
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies CIF and name matches while excluding the edited Account.
	 */
	@IsTest
	static void findsFiscalAndNameCandidatesExcludingCurrentAccount() {
		Account currentAccount = createAccount('Veolia Current', '12345678Z');
		Account fiscalMatch = createAccount('Veolia Fiscal Match', 'X1234567L');
		Account nameMatch = createAccount('Veolia Name Match', 'A58818501');
		insert new List<Account>{ currentAccount, fiscalMatch, nameMatch };

		Test.startTest();
		List<VL_AccountDuplicateController.DuplicateMatch> matches = VL_AccountDuplicateController.findDuplicates(
			currentAccount.Id,
			' x1234567-l ',
			'Veolia'
		);
		Test.stopTest();

		System.assertEquals(2, matches.size(), 'The search should return the fiscal and name candidates.');
		System.assertNotEquals(currentAccount.Id, matches[0].accountId, 'The edited Account must be excluded.');
		System.assertNotEquals(currentAccount.Id, matches[1].accountId, 'The edited Account must be excluded.');
		System.assertEquals('CIF', matches[0].matchType, 'The fiscal candidate should be identified as CIF.');
	}

	private static Account createAccount(String accountName, String fiscalNumber) {
		Account account = VL_TestDataFactory.buildAccount(accountName, null, null, null, null, null, null);
		account.VL_FiscalNumber__c = fiscalNumber;
		return account;
	}

	/**
	 * @name: emptyCriteriaReturnsNoCandidates
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that empty search criteria do not query or return Accounts.
	 */
	@IsTest
	static void emptyCriteriaReturnsNoCandidates() {
		Test.startTest();
		List<VL_AccountDuplicateController.DuplicateMatch> matches = VL_AccountDuplicateController.findDuplicates(null, null, ' ');
		Test.stopTest();

		System.assertEquals(0, matches.size(), 'Empty criteria must return no candidates.');
	}
}