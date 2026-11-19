/**
 * @name VL_CustomDonutChartControllerTest
 * @version 1.0
 * @creation date 04/09/2026
 * @author Jesus Piriz
 * @description Tests for VL_CustomDonutChartController generic dispatcher.
 */
@IsTest
private with sharing class VL_CustomDonutChartControllerTest {
	/**
	 * @name setupData
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates an Account with opportunities so the delegated controller returns data.
	 */
	@TestSetup
	static void setupData() {
		Account account = VL_TestDataFactory.createAccount('Donut Chart Account', null);
		VL_Company__c company = VL_TestDataFactory.createCompany();
		insert new List<Opportunity>{
			new Opportunity(
				Name = 'Open Opp',
				AccountId = account.Id,
				VL_Company__c = company.Id,
				StageName = 'Prospecting',
				CloseDate = Date.today().addDays(30)
			),
			new Opportunity(
				Name = 'Won Opp',
				AccountId = account.Id,
				VL_Company__c = company.Id,
				StageName = 'Closed Won',
				CloseDate = Date.today()
			),
			new Opportunity(
				Name = 'Lost Opp',
				AccountId = account.Id,
				VL_Company__c = company.Id,
				StageName = 'Closed Lost',
				CloseDate = Date.today()
			)
		};
	}

	/**
	 * @name: getDataDelegatesToConfiguredController
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies the generic controller instantiates the configured class and returns its chart data.
	 */
	@IsTest
	static void getDataDelegatesToConfiguredController() {
		Id accountId = [SELECT Id FROM Account WHERE Name = 'Donut Chart Account' LIMIT 1].Id;

		Test.startTest();
		List<VL_CustomChartData> result = VL_CustomDonutChartController.getData('VL_OpportunityStatusChartController', accountId);
		Test.stopTest();

		System.assertEquals(1, result.size(), 'The delegated controller should return one chart data element.');
		System.assertEquals(3, result[0].labels.size(), 'The status chart should expose the three fixed statuses.');
	}

	/**
	 * @name: getDataReturnsEmptyWhenControllerHasNoData
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies the dispatcher returns the delegated empty result for a blank filter.
	 */
	@IsTest
	static void getDataReturnsEmptyWhenControllerHasNoData() {
		Test.startTest();
		List<VL_CustomChartData> result = VL_CustomDonutChartController.getData('VL_OpportunityStatusChartController', '');
		Test.stopTest();

		System.assertEquals(0, result.size(), 'A blank filter should return an empty chart data list.');
	}
}