/**
 * @name: VL_AccountHelperTest
 * @version: 1.0
 * @creation date: 01/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Tests for Account fiscal-number validation and KAM synchronization entry points.
 */
@IsTest
private with sharing class VL_AccountHelperTest {
	/**
	 * @name: duplicateFiscalNumberOnInsertIsRejected
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that two new Accounts cannot share a fiscal number in one transaction.
	 */
	@IsTest
	static void duplicateFiscalNumberOnInsertIsRejected() {
		Account firstAccount = createAccount('First Account', '12345678Z');
		insert firstAccount;

		Account duplicateAccount = createAccount('Duplicate Account', ' 12345678z ');
		Test.startTest();
		Database.SaveResult result = Database.insert(duplicateAccount, false);
		Test.stopTest();

		System.assertEquals(false, result.isSuccess(), 'A duplicate fiscal number must be rejected.');
		System.assert(result.getErrors()[0].getMessage().contains('El CIF ya existe'), 'The error should identify the fiscal number.');
	}

	/**
	 * @name: duplicateFiscalNumberOnUpdateIsRejected
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that changing an existing Account to another Account fiscal number is rejected.
	 */
	@IsTest
	static void duplicateFiscalNumberOnUpdateIsRejected() {
		Account firstAccount = createAccount('First Account', '23456789D');
		Account secondAccount = createAccount('Second Account', '34567890V');
		insert new List<Account>{ firstAccount, secondAccount };

		secondAccount.VL_FiscalNumber__c = '23456789D';
		Test.startTest();
		Database.SaveResult result = Database.update(secondAccount, false);
		Test.stopTest();

		System.assertEquals(false, result.isSuccess(), 'Changing to an existing fiscal number must be rejected.');
		System.assert(result.getErrors()[0].getMessage().contains('El CIF ya existe'), 'The error should identify the fiscal number.');
	}

	/**
	 * @name: unchangedFiscalNumberOnUpdateIsAllowed
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that an update which does not change the fiscal number is not rejected by the duplicate check.
	 */
	@IsTest
	static void unchangedFiscalNumberOnUpdateIsAllowed() {
		Account account = createAccount('Editable Account', '34567890V');
		insert account;

		account.Description = 'Updated description';
		Test.startTest();
		Database.SaveResult result = Database.update(account, false);
		Test.stopTest();

		System.assertEquals(true, result.isSuccess(), 'An unchanged fiscal number should remain valid.');
	}

	/**
	 * @name: fiscalNumberIsCanonicalizedOnInsert
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that separators and lowercase characters are removed before persistence.
	 */
	@IsTest
	static void fiscalNumberIsCanonicalizedOnInsert() {
		Account account = createAccount('Canonical Account', ' 12345678-z ');

		Test.startTest();
		insert account;
		Test.stopTest();

		Account savedAccount = [SELECT VL_FiscalNumber__c FROM Account WHERE Id = :account.Id];
		System.assertEquals('12345678Z', savedAccount.VL_FiscalNumber__c, 'The fiscal number must be stored canonically.');
	}

	/**
	 * @name: duplicateAccountNameOnInsertIsRejected
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that a normalized duplicate Account name is rejected.
	 */
	@IsTest
	static void duplicateAccountNameOnInsertIsRejected() {
		Account firstAccount = createAccount('Veolia Iberia', '78901234X');
		insert firstAccount;

		Account duplicateAccount = createAccount('  veolia iberia  ', '89012345E');
		Test.startTest();
		Database.SaveResult result = Database.insert(duplicateAccount, false);
		Test.stopTest();

		System.assertEquals(false, result.isSuccess(), 'A normalized duplicate Account name must be rejected.');
		System.assert(result.getErrors()[0].getMessage().contains('nombre de Account'), 'The error should identify the duplicate name rule.');
	}

	/**
	 * @name: duplicateFiscalNumberWithinInsertBatchIsRejected
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that duplicate fiscal numbers within one insert batch are rejected.
	 */
	@IsTest
	static void duplicateFiscalNumberWithinInsertBatchIsRejected() {
		List<Account> accounts = new List<Account>{
			createAccount('Batch Fiscal First', '90123456A'),
			createAccount('Batch Fiscal Second', '90123456A')
		};

		Test.startTest();
		Database.SaveResult[] results = Database.insert(accounts, false);
		Test.stopTest();

		System.assertEquals(false, results[0].isSuccess(), 'The first batch record must be rejected.');
		System.assertEquals(false, results[1].isSuccess(), 'The second batch record must be rejected.');
	}

	/**
	 * @name: duplicateAccountNameWithinInsertBatchIsRejected
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that normalized duplicate names within one insert batch are rejected.
	 */
	@IsTest
	static void duplicateAccountNameWithinInsertBatchIsRejected() {
		List<Account> accounts = new List<Account>{ createAccount('Batch Name', '91234567B'), createAccount(' batch name ', '92345678C') };

		Test.startTest();
		Database.SaveResult[] results = Database.insert(accounts, false);
		Test.stopTest();

		System.assertEquals(false, results[0].isSuccess(), 'The first batch record must be rejected.');
		System.assertEquals(false, results[1].isSuccess(), 'The second batch record must be rejected.');
	}

	private static Account createAccount(String accountName, String fiscalNumber) {
		Account account = VL_TestDataFactory.buildAccount(accountName, null, null, null, null, null, null);
		account.VL_FiscalNumber__c = fiscalNumber;
		return account;
	}
}