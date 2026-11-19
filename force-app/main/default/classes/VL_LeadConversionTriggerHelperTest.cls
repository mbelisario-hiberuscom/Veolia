/**
 * @name: VL_LeadConversionTriggerHelperTest
 * @version: 1.0
 * @creation date: 10/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description: Tests real Lead conversion mapping to Opportunity typology and source fields.
 */
@IsTest
private with sharing class VL_LeadConversionTriggerHelperTest {
	/**
	 * @name: convertedPrivateLeadMapsOpportunityData
	 * @creation date: 10/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies conversion of a private Lead assigns the new-contract Opportunity Record Type.
	 */
	@IsTest
	static void convertedPrivateLeadMapsOpportunityData() {
		Database.LeadConvertResult conversionResult = convertLead('Privado', 'Private', 'Directa');
		Opportunity opportunity = getConvertedOpportunity(conversionResult);

		System.assertEquals(
			'VL_NuevaContratacion',
			opportunity.RecordType.DeveloperName,
			'Private Leads should create new-contract Opportunities.'
		);
		System.assertEquals('Web', opportunity.LeadSource, 'LeadSource should be preserved.');
		System.assertEquals('Directa', opportunity.VL_Origen__c, 'Origin should be preserved.');
		System.assertEquals('Privada', opportunity.VL_ContractType__c, 'Contract type should be preserved.');
	}

	/**
	 * @name: convertedPublicLeadMapsPublicTenderOpportunity
	 * @creation date: 10/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies conversion of a public Lead assigns the public-tender Opportunity Record Type.
	 */
	@IsTest
	static void convertedPublicLeadMapsPublicTenderOpportunity() {
		Database.LeadConvertResult conversionResult = convertLead('Administración Pública', 'Public', 'Directa');
		Opportunity opportunity = getConvertedOpportunity(conversionResult);

		System.assertEquals(
			'VL_LicitacionPublica',
			opportunity.RecordType.DeveloperName,
			'Public Leads should create public-tender Opportunities.'
		);
		System.assertEquals('Web', opportunity.LeadSource, 'LeadSource should be preserved.');
		System.assertEquals('Directa', opportunity.VL_Origen__c, 'Origin should be preserved.');
		System.assertEquals('Privada', opportunity.VL_ContractType__c, 'Contract type should be preserved.');
	}

	/**
	 * @name: convertedRenewalLeadMapsRenewalOpportunity
	 * @creation date: 11/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that a renewal origin assigns the renewal Opportunity Record Type.
	 */
	@IsTest
	static void convertedRenewalLeadMapsRenewalOpportunity() {
		Database.LeadConvertResult conversionResult = convertLead('Privado', 'Renewal', 'Renovación');
		Opportunity opportunity = getConvertedOpportunity(conversionResult);

		System.assertEquals('VL_Renovacion', opportunity.RecordType.DeveloperName, 'Renewal Leads should create renewal Opportunities.');
	}

	/**
	 * @name: convertedUpsellLeadMapsExpansionOpportunity
	 * @creation date: 11/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that an up-selling origin assigns the expansion Opportunity Record Type.
	 */
	@IsTest
	static void convertedUpsellLeadMapsExpansionOpportunity() {
		Database.LeadConvertResult conversionResult = convertLead('Privado', 'Upsell', 'Up-Selling');
		Opportunity opportunity = getConvertedOpportunity(conversionResult);

		System.assertEquals('VL_Ampliacion', opportunity.RecordType.DeveloperName, 'Up-selling Leads should create expansion Opportunities.');
	}

	/**
	 * @name: convertedCrossSellLeadMapsCrossSellingOpportunity
	 * @creation date: 11/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that a cross-selling origin assigns the cross-selling Opportunity Record Type.
	 */
	@IsTest
	static void convertedCrossSellLeadMapsCrossSellingOpportunity() {
		Database.LeadConvertResult conversionResult = convertLead('Privado', 'CrossSell', 'Cross-Selling');
		Opportunity opportunity = getConvertedOpportunity(conversionResult);

		System.assertEquals(
			'VL_CrossSelling',
			opportunity.RecordType.DeveloperName,
			'Cross-selling Leads should create cross-selling Opportunities.'
		);
	}

	private static Database.LeadConvertResult convertLead(String leadType, String suffix, String origin) {
		Account account = new Account(
			Name = 'Lead Conversion Account ' + suffix,
			Type = 'Privado',
			Phone = '900000002',
			VL_FiscalNumber__c = suffix == 'Private' ? '12345678Z' : '23456789D',
			VL_KAM__c = UserInfo.getUserId(),
			VL_Market__c = getFirstPicklistValue(Account.VL_Market__c),
			VL_MarketSegment__c = getFirstPicklistValue(Account.VL_MarketSegment__c),
			VL_MegaMarket__c = getFirstPicklistValue(Account.VL_MegaMarket__c)
		);
		insert account;
		Contact contact = new Contact(
			LastName = 'Conversion Contact ' + suffix,
			AccountId = account.Id,
			Email = 'contact.' + suffix.toLowerCase() + '@example.com'
		);
		setContactFieldValue(contact, 'VL_Ambit__c');
		insert contact;

		VL_BusinessGroup__c businessGroup = new VL_BusinessGroup__c(Name = 'Lead Conversion Group ' + suffix);
		insert businessGroup;
		VL_Company__c company = VL_TestDataFactory.createCompany();
		Opportunity opportunity = new Opportunity(
			Name = 'Converted Opportunity ' + suffix,
			AccountId = account.Id,
			CloseDate = Date.today().addDays(30),
			StageName = 'Prospecting',
			VL_ContractType__c = 'Privada',
			VL_Company__c = company.Id
		);
		insert opportunity;

		Lead lead = new Lead(
			FirstName = 'Conversion',
			LastName = 'Test ' + suffix,
			Company = 'Converted Company ' + suffix,
			Email = 'conversion.' + suffix.toLowerCase() + '@example.com',
			OwnerId = UserInfo.getUserId(),
			Status = getLeadStatus(false),
			LeadSource = 'Web',
			VL_FiscalNumber__c = suffix == 'Private' ? '12345678Z' : '23456789D',
			VL_Type__c = leadType,
			VL_MegaMarket__c = getFirstPicklistValue(Lead.VL_MegaMarket__c),
			VL_Market__c = getFirstPicklistValue(Lead.VL_Market__c),
			VL_MarketSegment__c = getFirstPicklistValue(Lead.VL_MarketSegment__c),
			VL_CustomerPriority__c = getFirstPicklistValue(Lead.VL_CustomerPriority__c),
			VL_BusinessGroup__c = businessGroup.Id,
			VL_Origen__c = origin,
			VL_ContractType__c = 'Privada'
		);
		setLeadFieldValue(lead, 'VL_Ambit__c');
		insert lead;

		Database.LeadConvert leadConvert = new Database.LeadConvert();
		leadConvert.setLeadId(lead.Id);
		leadConvert.setAccountId(account.Id);
		leadConvert.setContactId(contact.Id);
		leadConvert.setOpportunityId(opportunity.Id);
		leadConvert.setConvertedStatus(getLeadStatus(true));

		Test.startTest();
		Database.LeadConvertResult result = Database.convertLead(leadConvert);
		Test.stopTest();

		System.assert(result.isSuccess(), 'Lead conversion should succeed.');
		System.assertNotEquals(null, result.getOpportunityId(), 'Conversion should create an Opportunity.');
		return result;
	}

	private static Opportunity getConvertedOpportunity(Database.LeadConvertResult conversionResult) {
		return [
			SELECT RecordType.DeveloperName, LeadSource, VL_Origen__c, VL_ContractType__c
			FROM Opportunity
			WHERE Id = :conversionResult.getOpportunityId()
		];
	}

	private static String getLeadStatus(Boolean isConverted) {
		return [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = :isConverted LIMIT 1].MasterLabel;
	}

	private static String getFirstPicklistValue(Schema.SObjectField fieldToken) {
		for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
			if (entry.isActive()) {
				return entry.getValue();
			}
		}
		return null;
	}

	private static void setLeadFieldValue(Lead lead, String fieldName) {
		setLeadFieldValue(lead, fieldName, null);
	}

	private static void setLeadFieldValue(Lead lead, String fieldName, Object fieldValue) {
		Map<String, Schema.SObjectField> fieldsByName = Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap();
		if (!fieldsByName.containsKey(fieldName)) {
			return;
		}
		Schema.DescribeFieldResult fieldDescribe = fieldsByName.get(fieldName).getDescribe();
		if (fieldValue != null) {
			lead.put(fieldName, fieldValue);
			return;
		}
		if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
			lead.put(fieldName, getFirstPicklistValue(fieldsByName.get(fieldName)));
			return;
		}
		lead.put(fieldName, 'Test');
	}

	private static void setContactFieldValue(Contact contact, String fieldName) {
		Map<String, Schema.SObjectField> fieldsByName = Schema.getGlobalDescribe().get('Contact').getDescribe().fields.getMap();
		if (!fieldsByName.containsKey(fieldName)) {
			return;
		}
		Schema.DescribeFieldResult fieldDescribe = fieldsByName.get(fieldName).getDescribe();
		if (fieldDescribe.getType() == Schema.DisplayType.MultiPicklist) {
			contact.put(fieldName, getFirstPicklistValue(fieldsByName.get(fieldName)));
			return;
		}
		contact.put(fieldName, 'Test');
	}
}