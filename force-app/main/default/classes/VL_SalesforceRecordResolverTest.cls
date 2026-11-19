/**
 * @name VL_SalesforceRecordResolverTest
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Tests for VL_SalesforceRecordResolver dynamic record resolution.
 **/
@IsTest
private class VL_SalesforceRecordResolverTest {
	@TestSetup
	static void setupData() {
		User testUser = VL_TestDataFactory.createGoogleDriveTestUser();
		System.runAs(testUser) {
			Account acc = VL_TestDataFactory.createAccount('Test Account Resolver', null);
			VL_TestDataFactory.createLead('Test', 'Lead Resolver', 'Acme', 'resolver@test.com');
			VL_TestDataFactory.createOpportunity('Test Opp Resolver', acc);
		}
	}

	/**
	 * @name: resolveAccountReturnsObjectApiNameAndName
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that an Account Id resolves to objectApiName=Account and the record Name.
	 */
	@IsTest
	static void resolveAccountReturnsObjectApiNameAndName() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account Resolver' LIMIT 1];

			Test.startTest();
			Map<Id, VL_ResolvedRecord> result = VL_SalesforceRecordResolver.resolve(new Set<Id>{ acc.Id });
			Test.stopTest();

			System.assertEquals(1, result.size(), 'Should resolve exactly one record');
			VL_ResolvedRecord resolved = result.get(acc.Id);
			System.assertNotEquals(null, resolved, 'Resolved record should not be null');
			System.assertEquals('Account', resolved.objectApiName, 'Object API name should be Account');
			System.assertEquals('Test Account Resolver', resolved.recordName, 'Record name should match');
		}
	}

	/**
	 * @name: resolveLeadReturnsObjectApiNameAndName
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that a Lead Id resolves to objectApiName=Lead and the record Name.
	 */
	@IsTest
	static void resolveLeadReturnsObjectApiNameAndName() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Lead ld = [SELECT Id, Name FROM Lead WHERE LastName = 'Lead Resolver' LIMIT 1];

			Test.startTest();
			Map<Id, VL_ResolvedRecord> result = VL_SalesforceRecordResolver.resolve(new Set<Id>{ ld.Id });
			Test.stopTest();

			VL_ResolvedRecord resolved = result.get(ld.Id);
			System.assertNotEquals(null, resolved, 'Resolved record should not be null');
			System.assertEquals('Lead', resolved.objectApiName, 'Object API name should be Lead');
		}
	}

	/**
	 * @name: resolveEmptySetReturnsEmptyMap
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that passing an empty set returns an empty map without SOQL.
	 */
	@IsTest
	static void resolveEmptySetReturnsEmptyMap() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			Map<Id, VL_ResolvedRecord> result = VL_SalesforceRecordResolver.resolve(new Set<Id>());
			Test.stopTest();

			System.assertEquals(0, result.size(), 'Empty input should return empty map');
		}
	}

	/**
	 * @name: resolveBulk200MixedIdsUsesOneQueryPerType
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that 200 mixed-type Ids are resolved with one query per sObject type.
	 */
	@IsTest
	static void resolveBulk200MixedIdsUsesOneQueryPerType() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			VL_CNAE__c cnae = VL_TestDataFactory.createCNAE('Bulk Resolver CNAE');
			List<String> accountNames = new List<String>();
			for (Integer i = 0; i < 100; i++) {
				accountNames.add(String.valueOf(Crypto.getRandomLong()));
			}
			List<Account> accounts = VL_TestDataFactory.createAccounts(accountNames, cnae);
			List<Lead> leads = VL_TestDataFactory.createLeads(100);

			Set<Id> mixedIds = new Set<Id>();
			for (Account a : accounts) {
				mixedIds.add(a.Id);
			}
			for (Lead l : leads) {
				mixedIds.add(l.Id);
			}

			Integer queriesBefore = Limits.getQueries();
			Test.startTest();
			Map<Id, VL_ResolvedRecord> result = VL_SalesforceRecordResolver.resolve(mixedIds);
			Integer queriesAfter = Limits.getQueries();
			Test.stopTest();

			System.assertEquals(200, result.size(), 'All 200 records should be resolved');
			System.assert(queriesAfter - queriesBefore <= 2, 'Should issue at most one query per sObject type (2 types)');
		}
	}

	/**
	 * @name: resolveNullSetReturnsEmptyMap
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Verifies that passing null returns an empty map safely.
	 */
	@IsTest
	static void resolveNullSetReturnsEmptyMap() {
		System.runAs(VL_TestDataFactory.getGoogleDriveTestUser()) {
			Test.startTest();
			Map<Id, VL_ResolvedRecord> result = VL_SalesforceRecordResolver.resolve(null);
			Test.stopTest();

			System.assertEquals(0, result.size(), 'Null input should return empty map');
		}
	}
}