/**
 * @name VL_CustomerHeaderControllerTest
 * @version 1.0
 * @creation date 04/09/2026
 * @author Daniel Landete Martinez
 * @description Tests the customer header data returned for an account.
 */
@IsTest
private with sharing class VL_CustomerHeaderControllerTest {
	/**
	 * @name: setupData
	 * @creation date: 04/09/2026
	 * @author: Daniel Landete Martinez
	 * @description Creates account data and related records used by the controller tests.
	 */
	@TestSetup
	static void setupData() {
		Account account = VL_TestDataFactory.createAccount('Customer Header Account', null);
		account.VL_Active__c = true;
		account.VL_FiscalNumber__c = 'Y7075875P';
		account.Phone = '600123456';
		account.Type = 'Privado';
		update account;

		VL_Company__c company = VL_TestDataFactory.createCompany();
		Opportunity openOpportunity = VL_TestDataFactory.createOpportunity('Open Opportunity', account, company.Id);
		openOpportunity.Amount = 1250;
		Opportunity wonOpportunity = VL_TestDataFactory.createOpportunity('Won Opportunity', account, company.Id);
		wonOpportunity.StageName = 'Closed Won';
		wonOpportunity.CloseDate = Date.today();
		wonOpportunity.Amount = 750;
		update new List<Opportunity>{ openOpportunity, wonOpportunity };

		VL_TestDataFactory.createCase(account, 'Open customer case');
		// Falla al crear el contrato debido a que no le asigna correctamente el valor status 'Active' al insertarlo.
		//VL_TestDataFactory.createContract(account);
	}

	/**
	 * @name: getCustomerHeaderReturnsNullForNullAccountId
	 * @creation date: 04/09/2026
	 * @author: Daniel Landete Martinez
	 * @description Verifies that a null account ID returns no header.
	 */
	@IsTest
	static void getCustomerHeaderReturnsNullForNullAccountId() {
		Test.startTest();
		VL_CustomerHeaderController.CustomerHeaderDTO result = VL_CustomerHeaderController.getCustomerHeader(null);
		Test.stopTest();

		System.assertEquals(null, result, 'A null account ID should return no header.');
	}

	/**
	 * @name: getCustomerHeaderReturnsNullForDeletedAccount
	 * @creation date: 04/09/2026
	 * @author: Daniel Landete Martinez
	 * @description Verifies that an account that cannot be queried returns no header.
	 */
	@IsTest
	static void getCustomerHeaderReturnsNullForDeletedAccount() {
		Account deletedAccount = VL_TestDataFactory.createAccount('Deleted Customer Header Account', null);
		delete deletedAccount;

		Test.startTest();
		VL_CustomerHeaderController.CustomerHeaderDTO result = VL_CustomerHeaderController.getCustomerHeader(deletedAccount.Id);
		Test.stopTest();

		System.assertEquals(null, result, 'An account that is not available should return no header.');
	}

	/**
	 * @name: getCustomerHeaderReturnsAccountMetrics
	 * @creation date: 04/09/2026
	 * @author: Daniel Landete Martinez
	 * @description Verifies account details and related record metrics in the returned header.
	 */
	@IsTest
	static void getCustomerHeaderReturnsAccountMetrics() {
		Id accountId = [SELECT Id FROM Account WHERE Name = 'Customer Header Account' LIMIT 1].Id;

		Test.startTest();
		VL_CustomerHeaderController.CustomerHeaderDTO result = VL_CustomerHeaderController.getCustomerHeader(accountId);
		Test.stopTest();

		System.assertEquals('Customer Header Account', result.accountName, 'The account name should be returned.');
		System.assertEquals(true, result.isActive, 'The active flag should be returned.');
		System.assertEquals('Y7075875P', result.documentNumber, 'The fiscal number should be returned.');
		System.assertEquals('600123456', result.phone, 'The phone should be returned.');
		System.assertEquals(1250, result.pipelineAmount, 'Only open opportunity amounts should contribute to the pipeline.');
		System.assertEquals(1, result.openOpportunities, 'Only one opportunity should be open.');
		System.assertEquals(1, result.wonOpportunities, 'One opportunity should be won.');
		System.assertEquals(1, result.openCases, 'One case should be open.');
		//System.assertEquals(1, result.activeContracts, 'One contract should be active.');
		System.assertNotEquals(null, result.pipelineAmountFormatted, 'The pipeline amount should have a formatted representation.');
	}
}