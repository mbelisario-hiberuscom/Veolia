/**
 * @name VL_OpportunityStatusChartControllerTest
 * @version 1.0
 * @creation date 04/09/2026
 * @author Jesus Piriz
 * @description Tests for VL_OpportunityStatusChartController donut chart data building.
 */
@IsTest
private with sharing class VL_OpportunityStatusChartControllerTest {
	/**
	 * @name setupData
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates an Account with open, won and lost opportunities plus an Account without opportunities.
	 */
	@TestSetup
	static void setupData() {
		Account account = VL_TestDataFactory.createAccount('Status Chart Account', null);
		VL_TestDataFactory.createAccount('Status Chart Empty Account', null, true);
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
	 * @name: getDataReturnsEmptyForBlankFilter
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies a blank filter returns an empty chart data list.
	 */
	@IsTest
	static void getDataReturnsEmptyForBlankFilter() {
		Test.startTest();
		List<VL_CustomChartData> result = new VL_OpportunityStatusChartController().getData('');
		Test.stopTest();

		System.assertEquals(0, result.size(), 'A blank filter should return an empty list.');
	}

	/**
	 * @name: getDataReturnsEmptyForInvalidId
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies a filter that is not a valid Id returns an empty chart data list.
	 */
	@IsTest
	static void getDataReturnsEmptyForInvalidId() {
		Test.startTest();
		List<VL_CustomChartData> result = new VL_OpportunityStatusChartController().getData('not-an-id');
		Test.stopTest();

		System.assertEquals(0, result.size(), 'An invalid Id should return an empty list.');
	}

	/**
	 * @name: getDataReturnsEmptyForAccountWithoutOpportunities
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies an Account without opportunities returns an empty chart data list.
	 */
	@IsTest
	static void getDataReturnsEmptyForAccountWithoutOpportunities() {
		Id emptyAccountId = [SELECT Id FROM Account WHERE Name = 'Status Chart Empty Account' LIMIT 1].Id;

		Test.startTest();
		List<VL_CustomChartData> result = new VL_OpportunityStatusChartController().getData(emptyAccountId);
		Test.stopTest();

		System.assertEquals(0, result.size(), 'An Account without opportunities should return an empty list.');
	}

	/**
	 * @name: getDataBuildsStatusChartForAccountWithOpportunities
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies the donut chart groups opportunities into the fixed Vivas, Ganadas and Perdidas statuses.
	 */
	@IsTest
	static void getDataBuildsStatusChartForAccountWithOpportunities() {
		Id accountId = [SELECT Id FROM Account WHERE Name = 'Status Chart Account' LIMIT 1].Id;

		Test.startTest();
		List<VL_CustomChartData> result = new VL_OpportunityStatusChartController().getData(accountId);
		Test.stopTest();

		System.assertEquals(1, result.size(), 'One chart data element should be returned.');
		VL_CustomChartData chartData = result[0];
		System.assertEquals(3, chartData.labels.size(), 'The chart should expose the three fixed statuses.');
		System.assertEquals('Vivas', chartData.labels[0].value, 'The first label should be the alive status.');

		List<String> values = chartData.datasets[0].values;
		System.assertEquals(1, Decimal.valueOf(values[0]), 'There should be one open opportunity.');
		System.assertEquals(1, Decimal.valueOf(values[1]), 'There should be one won opportunity.');
		System.assertEquals(1, Decimal.valueOf(values[2]), 'There should be one lost opportunity.');
	}
}