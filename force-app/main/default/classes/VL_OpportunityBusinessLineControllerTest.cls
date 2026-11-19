/**
 * @name VL_OpportunityBusinessLineControllerTest
 * @version 1.0
 * @creation date 04/09/2026
 * @author Jesus Piriz
 * @description Tests for VL_OpportunityBusinessLineController stacked bar chart data building.
 */
@IsTest
private with sharing class VL_OpportunityBusinessLineControllerTest {
	private static final String BUSINESS_LINE_FIELD = 'VL_BusinessLine__c';

	/**
	 * @name resolveBusinessLineValue
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Resolves a valid VL_BusinessLine__c value based on the field type so tests stay org-agnostic.
	 * @return A value assignable to Opportunity.VL_BusinessLine__c, or null when it cannot be resolved.
	 */
	private static Object resolveBusinessLineValue() {
		Schema.SObjectField businessLineField = Opportunity.SObjectType.getDescribe().fields.getMap().get(BUSINESS_LINE_FIELD);
		if (businessLineField == null) {
			return null;
		}
		Schema.DescribeFieldResult fieldDescribe = businessLineField.getDescribe();
		Schema.DisplayType fieldType = fieldDescribe.getType();
		if (fieldType == Schema.DisplayType.PICKLIST || fieldType == Schema.DisplayType.MULTIPICKLIST) {
			List<Schema.PicklistEntry> entries = fieldDescribe.getPicklistValues();
			return entries.isEmpty() ? null : entries[0].getValue();
		}
		if (fieldType == Schema.DisplayType.STRING || fieldType == Schema.DisplayType.TEXTAREA) {
			return 'Agua';
		}
		if (fieldType == Schema.DisplayType.REFERENCE) {
			SObject parent = fieldDescribe.getReferenceTo()[0].newSObject();
			parent.put('Name', 'Test Business Line');
			insert parent;
			return parent.Id;
		}
		return null;
	}

	/**
	 * @name setupData
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Creates an Account with opportunities grouped by business line and one Account without a business line.
	 */
	@TestSetup
	static void setupData() {
		Account account = VL_TestDataFactory.createAccount('Business Line Account', null);
		VL_TestDataFactory.createAccount('Business Line Empty Account', null, true);
		VL_Company__c company = VL_TestDataFactory.createCompany();

		Object businessLineValue = resolveBusinessLineValue();
		List<Opportunity> opportunities = new List<Opportunity>{
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
		if (businessLineValue != null) {
			for (Opportunity opportunity : opportunities) {
				opportunity.put(BUSINESS_LINE_FIELD, businessLineValue);
			}
		}
		insert opportunities;
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
		List<VL_CustomChartData> result = new VL_OpportunityBusinessLineController().getData('');
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
		List<VL_CustomChartData> result = new VL_OpportunityBusinessLineController().getData('not-an-id');
		Test.stopTest();

		System.assertEquals(0, result.size(), 'An invalid Id should return an empty list.');
	}

	/**
	 * @name: getDataReturnsEmptyWhenNoBusinessLine
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies an Account whose opportunities have no business line returns an empty chart data list.
	 */
	@IsTest
	static void getDataReturnsEmptyWhenNoBusinessLine() {
		Id emptyAccountId = [SELECT Id FROM Account WHERE Name = 'Business Line Empty Account' LIMIT 1].Id;

		Test.startTest();
		List<VL_CustomChartData> result = new VL_OpportunityBusinessLineController().getData(emptyAccountId);
		Test.stopTest();

		System.assertEquals(0, result.size(), 'Opportunities without a business line should return an empty list.');
	}

	/**
	 * @name: getDataBuildsStackedChartForAccountWithBusinessLine
	 * @creation date: 04/09/2026
	 * @author: Jesus Piriz
	 * @description Verifies the stacked chart exposes one dataset per status when opportunities have a business line.
	 */
	@IsTest
	static void getDataBuildsStackedChartForAccountWithBusinessLine() {
		if (resolveBusinessLineValue() == null) {
			return;
		}
		Id accountId = [SELECT Id FROM Account WHERE Name = 'Business Line Account' LIMIT 1].Id;

		Test.startTest();
		List<VL_CustomChartData> result = new VL_OpportunityBusinessLineController().getData(accountId);
		Test.stopTest();

		System.assertEquals(1, result.size(), 'One chart data element should be returned.');
		VL_CustomChartData chartData = result[0];
		System.assertEquals(true, chartData.showStacked, 'The chart should be flagged as stacked.');
		System.assertEquals(3, chartData.datasets.size(), 'There should be one dataset per opportunity status.');
		System.assertEquals(1, chartData.labels.size(), 'A single business line should produce a single label.');
	}
}