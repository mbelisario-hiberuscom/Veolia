/**
 * @name: VL_CollaborationTriggerHelperTest
 * @version: 1.0
 * @creation date: 10/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description: Tests the primary collaboration constraint per Opportunity.
 */
@IsTest
private with sharing class VL_CollaborationTriggerHelperTest {
	/**
	 * @name: preventsMultiplePrimaryCollaborations
	 * @creation date: 10/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that an Opportunity cannot have two primary collaborations.
	 */
	@IsTest
	static void preventsMultiplePrimaryCollaborations() {
		Opportunity opportunity = createOpportunity();
		insert createCollaboration(opportunity.Id, true, 'Primary');

		Database.SaveResult result = Database.insert(createCollaboration(opportunity.Id, true, 'Duplicate'), false);

		System.assertEquals(false, result.isSuccess(), 'A second primary collaboration must be rejected.');
		System.assert(
			result.getErrors()[0].getMessage().contains('Only one primary collaboration'),
			'The rejection should explain the primary constraint.'
		);
	}

	/**
	 * @name: allowsNonPrimaryCollaboration
	 * @creation date: 10/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that a non-primary collaboration can coexist with the primary one.
	 */
	@IsTest
	static void allowsNonPrimaryCollaboration() {
		Opportunity opportunity = createOpportunity();
		insert createCollaboration(opportunity.Id, true, 'Primary');

		Database.SaveResult result = Database.insert(createCollaboration(opportunity.Id, false, 'Secondary'), false);

		System.assertEquals(true, result.isSuccess(), 'A non-primary collaboration should be accepted.');
	}

	/**
	 * @name: leaderMustBePrimary
	 * @creation date: 11/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that a leader collaboration must be marked as primary.
	 */
	@IsTest
	static void leaderMustBePrimary() {
		Opportunity opportunity = createOpportunity();

		Database.SaveResult result = Database.insert(createCollaboration(opportunity.Id, false, 'LeaderWithoutPrimary', 'LIDER'), false);

		System.assertEquals(false, result.isSuccess(), 'A leader collaboration must be primary.');
		System.assert(result.getErrors()[0].getMessage().contains('must be the primary'), 'The role constraint should be explained.');
	}

	/**
	 * @name: collaboratorCannotBePrimary
	 * @creation date: 11/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that a collaborator collaboration cannot be marked as primary.
	 */
	@IsTest
	static void collaboratorCannotBePrimary() {
		Opportunity opportunity = createOpportunity();

		Database.SaveResult result = Database.insert(createCollaboration(opportunity.Id, true, 'CollaboratorPrimary', 'COLABORADORA'), false);

		System.assertEquals(false, result.isSuccess(), 'A collaborator collaboration cannot be primary.');
		System.assert(result.getErrors()[0].getMessage().contains('cannot be the primary'), 'The role constraint should be explained.');
	}

	private static Opportunity createOpportunity() {
		Account account = new Account(
			Name = 'Collaboration Test Account',
			Type = 'Privado',
			Phone = '900000001',
			VL_FiscalNumber__c = '12345678Z',
			VL_KAM__c = UserInfo.getUserId(),
			VL_Market__c = getFirstPicklistValue(Account.VL_Market__c),
			VL_MarketSegment__c = getFirstPicklistValue(Account.VL_MarketSegment__c),
			VL_MegaMarket__c = getFirstPicklistValue(Account.VL_MegaMarket__c)
		);
		insert account;
		VL_Company__c company = VL_TestDataFactory.createCompany();

		Opportunity opportunity = new Opportunity(
			Name = 'Collaboration Test Opportunity',
			AccountId = account.Id,
			CloseDate = Date.today().addDays(30),
			StageName = 'Prospecting',
			VL_ContractType__c = 'Privada',
			VL_Company__c = company.Id
		);
		insert opportunity;
		return opportunity;
	}

	private static VL_Collaboration__c createCollaboration(Id opportunityId, Boolean isPrimary, String suffix) {
		return createCollaboration(opportunityId, isPrimary, suffix, null);
	}

	private static VL_Collaboration__c createCollaboration(Id opportunityId, Boolean isPrimary, String suffix, String role) {
		return new VL_Collaboration__c(
			VL_Opportunity__c = opportunityId,
			VL_CollaborationType__c = 'UTE',
			VL_Status__c = 'Borrador',
			VL_IsPrimary__c = isPrimary,
			VL_RolePicklist__c = role,
			VL_UTENAme__c = 'Test UTE ' + suffix
		);
	}

	private static String getFirstPicklistValue(Schema.SObjectField fieldToken) {
		for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
			if (entry.isActive()) {
				return entry.getValue();
			}
		}
		return null;
	}
}