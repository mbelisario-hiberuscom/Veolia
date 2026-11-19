/**
 * @name VL_AccountRelationshipHelperTest
 * @version 1.0
 * @creation date: 07/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Tests Account relationship validation and Location KLM synchronization.
 */
@IsTest
private with sharing class VL_AccountRelationshipHelperTest {
	/**
	 * @name: emptyInputsReturnWithoutErrors
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that empty relationship inputs are ignored safely.
	 */
	@IsTest
	static void emptyInputsReturnWithoutErrors() {
		Test.startTest();
		VL_AccountRelationshipHelper.synchronizeLocationsKlm(null, null);
		VL_AccountRelationshipHelper.validateAccountDeactivation(null, null);
		Test.stopTest();
		System.assertEquals(true, true, 'Empty relationship inputs should return without errors.');
	}

	/**
	 * @name: deactivationWithoutCommercialContactIsBlocked
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that an Account without an active commercial Contact cannot be deactivated.
	 */
	@IsTest
	static void deactivationWithoutCommercialContactIsBlocked() {
		Account account = VL_TestDataFactory.createAccount('Relationship No Contact', null);
		Account oldAccount = new Account(Id = account.Id, VL_Active__c = true);
		Account newAccount = new Account(Id = account.Id, VL_Active__c = false);

		Test.startTest();
		VL_AccountRelationshipHelper.validateAccountDeactivation(
			new Map<Id, Account>{ account.Id => oldAccount },
			new Map<Id, Account>{ account.Id => newAccount }
		);
		Test.stopTest();

		System.assertEquals(true, newAccount.hasErrors(), 'An Account without a commercial Contact must be blocked.');
	}

	/**
	 * @name: deactivationWithOpenOpportunityIsBlocked
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that an open Opportunity blocks Account deactivation.
	 */
	@IsTest
	static void deactivationWithOpenOpportunityIsBlocked() {
		Account account = VL_TestDataFactory.createAccount('Relationship Open Opportunity', null);
		Opportunity opportunity = VL_TestDataFactory.createOpportunity('Open Opportunity', account);
		opportunity.StageName = 'Oferta presentada';
		update opportunity;
		Account oldAccount = new Account(Id = account.Id, VL_Active__c = true);
		Account newAccount = new Account(Id = account.Id, VL_Active__c = false);

		Test.startTest();
		VL_AccountRelationshipHelper.validateAccountDeactivation(
			new Map<Id, Account>{ account.Id => oldAccount },
			new Map<Id, Account>{ account.Id => newAccount }
		);
		Test.stopTest();

		System.assertEquals(true, newAccount.hasErrors(), 'An open Opportunity must block deactivation.');
	}

	/**
	 * @name: deactivationWithPendingActivitiesIsBlocked
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that pending Task and Event records block Account deactivation.
	 */
	@IsTest
	static void deactivationWithPendingActivitiesIsBlocked() {
		Account account = VL_TestDataFactory.createAccount('Relationship Pending Activities', null);
		insert new Task(WhatId = account.Id, Subject = 'Pending task', Status = 'Not Started', Priority = 'Normal');
		insert new Event(
			WhatId = account.Id,
			Subject = 'Pending event',
			StartDateTime = System.now().addDays(1),
			EndDateTime = System.now().addDays(1).addHours(1)
		);
		Account oldAccount = new Account(Id = account.Id, VL_Active__c = true);
		Account newAccount = new Account(Id = account.Id, VL_Active__c = false);

		Test.startTest();
		VL_AccountRelationshipHelper.validateAccountDeactivation(
			new Map<Id, Account>{ account.Id => oldAccount },
			new Map<Id, Account>{ account.Id => newAccount }
		);
		Test.stopTest();

		System.assertEquals(true, newAccount.hasErrors(), 'Pending activities must block deactivation.');
	}

	/**
	 * @name: deactivationWithCommercialContactIsAllowed
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that an active commercial Contact does not block deactivation by itself.
	 */
	@IsTest
	static void deactivationWithCommercialContactIsAllowed() {
		Account account = VL_TestDataFactory.createAccount('Relationship Commercial Contact', null);
		Contact contact = VL_TestDataFactory.createContact('Commercial Contact', account, 'commercial@example.com');
		contact.VL_ContactType__c = 'Comercial';
		update contact;
		Account oldAccount = new Account(Id = account.Id, VL_Active__c = true);
		Account newAccount = new Account(Id = account.Id, VL_Active__c = false);

		Test.startTest();
		VL_AccountRelationshipHelper.validateAccountDeactivation(
			new Map<Id, Account>{ account.Id => oldAccount },
			new Map<Id, Account>{ account.Id => newAccount }
		);
		Test.stopTest();

		System.assertEquals(false, newAccount.hasErrors(), 'A commercial Contact should allow deactivation when no other dependency exists.');
	}

	/**
	 * @name: synchronizeLocationsKlmReturnsWhenNoLocationsExist
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that KLM synchronization handles a changed KAM when no Locations exist.
	 */
	@IsTest
	static void synchronizeLocationsKlmReturnsWhenNoLocationsExist() {
		Account account = VL_TestDataFactory.createAccount('Relationship Location', null);
		User newKam = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId() LIMIT 1];
		Account oldAccount = new Account(Id = account.Id, VL_KAM__c = UserInfo.getUserId());
		Account newAccount = new Account(Id = account.Id, VL_KAM__c = newKam.Id);

		Test.startTest();
		VL_AccountRelationshipHelper.synchronizeLocationsKlm(
			new Map<Id, Account>{ account.Id => oldAccount },
			new Map<Id, Account>{ account.Id => newAccount }
		);
		Test.stopTest();

		System.assertEquals(false, newAccount.hasErrors(), 'KLM synchronization should tolerate an Account without Locations.');
	}

	/**
	 * @name: synchronizeLocationsKlmReturnsWhenKamIsUnchanged
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that unchanged KAM values do not trigger Location processing.
	 */
	@IsTest
	static void synchronizeLocationsKlmReturnsWhenKamIsUnchanged() {
		Account account = VL_TestDataFactory.createAccount('Relationship Unchanged KAM', null);
		Account oldAccount = new Account(Id = account.Id, VL_KAM__c = UserInfo.getUserId());
		Account newAccount = new Account(Id = account.Id, VL_KAM__c = UserInfo.getUserId());

		Test.startTest();
		VL_AccountRelationshipHelper.synchronizeLocationsKlm(
			new Map<Id, Account>{ account.Id => oldAccount },
			new Map<Id, Account>{ account.Id => newAccount }
		);
		Test.stopTest();

		System.assertEquals(false, newAccount.hasErrors(), 'An unchanged KAM should not produce errors.');
	}

	/**
	 * @name: deactivationWithActiveLocationIsBlocked
	 * @creation date: 07/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Verifies that an active Location blocks Account deactivation.
	 */
	@IsTest
	static void deactivationWithActiveLocationIsBlocked() {
		Account account = VL_TestDataFactory.createAccount('Relationship Active Location', null);
		createLocation(account.Id, UserInfo.getUserId());
		Account oldAccount = new Account(Id = account.Id, VL_Active__c = true);
		Account newAccount = new Account(Id = account.Id, VL_Active__c = false);

		Test.startTest();
		VL_AccountRelationshipHelper.validateAccountDeactivation(
			new Map<Id, Account>{ account.Id => oldAccount },
			new Map<Id, Account>{ account.Id => newAccount }
		);
		Test.stopTest();

		System.assertEquals(true, newAccount.hasErrors(), 'An active Location must block deactivation.');
	}

	private static Schema.Location createLocation(Id accountId, Id klmId) {
		VL_AutonomousCommunityRegion__c region = new VL_AutonomousCommunityRegion__c(
			Name = 'Test Region',
			VL_Code__c = '99',
			VL_Active__c = true
		);
		insert region;
		VL_Province__c province = new VL_Province__c(
			Name = 'Test Province',
			VL_Code__c = '99',
			VL_Active__c = true,
			VL_Autonomous_Community_Region__c = region.Id
		);
		insert province;
		VL_Municipality__c municipality = new VL_Municipality__c(
			Name = 'Test Municipality',
			VL_Province__c = province.Id,
			VL_Code__c = '99-999',
			VL_Code_INE__c = '99999'
		);
		insert municipality;
		Schema.Location location = new Schema.Location(
			Name = 'Test Location',
			VL_Account__c = accountId,
			VL_KLM__c = klmId,
			VL_Province__c = province.Id,
			VL_Municipality__c = municipality.Id,
			VL_Street__c = 'Test Street 1',
			VL_Postal_Code__c = '28001',
			VL_Active__c = true,
			VL_IsPrimary__c = false
		);
		insert location;
		return location;
	}
}