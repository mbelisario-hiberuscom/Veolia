/**
 * @name: VL_AccountRelationshipHelper
 * @version: 1.0
 * @creation date: 01/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Bulk-safe synchronization and validation for Account relationships.
 */
@SuppressWarnings('PMD.ApexDoc')
public inherited sharing class VL_AccountRelationshipHelper {
	private static final String COMMERCIAL_CONTACT_ERROR = 'An Account must retain at least one commercial Contact.';
	private static final String ACCOUNT_DEACTIVATION_ERROR = 'The Account cannot be deactivated while it has active dependencies or no active commercial Contact.';
	private static final Set<String> OPEN_OPPORTUNITY_STAGES = new Set<String>{
		'Oportunidad identificada',
		'Oportunidad cualificada',
		'Oferta en preparación',
		'Oferta en aprobación',
		'Oferta presentada'
	};

	public static void synchronizeLocationsKlm(Map<Id, Account> oldAccountsById, Map<Id, Account> accountsById) {
		if (oldAccountsById == null || oldAccountsById.isEmpty() || accountsById == null || accountsById.isEmpty()) {
			return;
		}

		Map<Id, Id> kamByAccountId = new Map<Id, Id>();
		for (Id accountId : accountsById.keySet()) {
			Account oldAccount = oldAccountsById.get(accountId);
			Account account = accountsById.get(accountId);
			if (oldAccount != null && oldAccount.VL_KAM__c != account.VL_KAM__c) {
				kamByAccountId.put(accountId, account.VL_KAM__c);
			}
		}
		if (kamByAccountId.isEmpty() || !Schema.sObjectType.Location.isAccessible() || !Schema.sObjectType.Location.isUpdateable()) {
			return;
		}

		List<Schema.Location> locationsToUpdate = new List<Schema.Location>();
		for (Schema.Location location : [SELECT Id, VL_Account__c, VL_KLM__c FROM Location WHERE VL_Account__c IN :kamByAccountId.keySet()]) {
			Id newKamId = kamByAccountId.get(location.VL_Account__c);
			if (location.VL_KLM__c != newKamId) {
				locationsToUpdate.add(new Schema.Location(Id = location.Id, VL_KLM__c = newKamId));
			}
		}
		if (!locationsToUpdate.isEmpty()) {
			Database.update(locationsToUpdate, AccessLevel.USER_MODE);
		}
	}

	public static void validateCommercialContactExists(Set<Id> accountIds) {
		if (accountIds == null || accountIds.isEmpty() || !Schema.sObjectType.Contact.isAccessible()) {
			return;
		}
		Set<Id> accountsWithCommercialContact = new Set<Id>();
		for (Contact contact : [
			SELECT AccountId
			FROM Contact
			WHERE AccountId IN :accountIds AND VL_Active__c = TRUE AND VL_Ambit__c INCLUDES ('Comercial')
		]) {
			accountsWithCommercialContact.add(contact.AccountId);
		}
		for (Id accountId : accountIds) {
			if (!accountsWithCommercialContact.contains(accountId)) {
				((Account) Trigger.newMap.get(accountId)).addError(COMMERCIAL_CONTACT_ERROR);
			}
		}
	}

	public static void validateAccountDeactivation(Map<Id, Account> oldAccountsById, Map<Id, Account> accountsById) {
		Set<Id> deactivatingAccountIds = getDeactivatingAccountIds(oldAccountsById, accountsById);
		if (deactivatingAccountIds.isEmpty()) {
			return;
		}
		Set<Id> blockedAccountIds = new Set<Id>();
		blockedAccountIds.addAll(getAccountsWithActiveLocations(deactivatingAccountIds));
		blockedAccountIds.addAll(getAccountsWithOpenOpportunities(deactivatingAccountIds));
		blockedAccountIds.addAll(getAccountsWithPendingActivities(deactivatingAccountIds));
		blockedAccountIds.addAll(getAccountsWithoutActiveCommercialContacts(deactivatingAccountIds));
		for (Id accountId : blockedAccountIds) {
			if (deactivatingAccountIds.contains(accountId)) {
				accountsById.get(accountId).addError(ACCOUNT_DEACTIVATION_ERROR);
			}
		}
	}

	private static Set<Id> getDeactivatingAccountIds(Map<Id, Account> oldAccountsById, Map<Id, Account> accountsById) {
		Set<Id> accountIds = new Set<Id>();
		if (oldAccountsById == null || oldAccountsById.isEmpty() || accountsById == null || accountsById.isEmpty()) {
			return accountIds;
		}
		for (Id accountId : accountsById.keySet()) {
			Account oldAccount = oldAccountsById.get(accountId);
			Account account = accountsById.get(accountId);
			if (oldAccount != null && oldAccount.VL_Active__c && !account.VL_Active__c) {
				accountIds.add(accountId);
			}
		}
		return accountIds;
	}

	private static Set<Id> getAccountsWithActiveLocations(Set<Id> accountIds) {
		Set<Id> blockedAccountIds = new Set<Id>();
		if (!Schema.sObjectType.Location.isAccessible()) {
			return blockedAccountIds;
		}
		for (Schema.Location location : [SELECT VL_Account__c FROM Location WHERE VL_Account__c IN :accountIds AND VL_Active__c = TRUE]) {
			blockedAccountIds.add(location.VL_Account__c);
		}
		return blockedAccountIds;
	}

	private static Set<Id> getAccountsWithOpenOpportunities(Set<Id> accountIds) {
		Set<Id> blockedAccountIds = new Set<Id>();
		if (!Schema.sObjectType.Opportunity.isAccessible()) {
			return blockedAccountIds;
		}
		for (Opportunity opportunity : [
			SELECT AccountId
			FROM Opportunity
			WHERE AccountId IN :accountIds AND StageName IN :OPEN_OPPORTUNITY_STAGES
		]) {
			blockedAccountIds.add(opportunity.AccountId);
		}
		return blockedAccountIds;
	}

	private static Set<Id> getAccountsWithPendingActivities(Set<Id> accountIds) {
		Set<Id> blockedAccountIds = new Set<Id>();
		if (!Schema.sObjectType.Task.isAccessible() || !Schema.sObjectType.Event.isAccessible()) {
			return blockedAccountIds;
		}
		Map<Id, Id> accountByContactId = new Map<Id, Id>();
		for (Contact contact : [SELECT Id, AccountId FROM Contact WHERE AccountId IN :accountIds]) {
			accountByContactId.put(contact.Id, contact.AccountId);
		}
		Set<Id> contactIds = accountByContactId.keySet();
		Set<Id> relatedRecordIds = new Set<Id>();
		Map<Id, Id> accountByRelatedId = new Map<Id, Id>();
		for (Id accountId : accountIds) {
			relatedRecordIds.add(accountId);
			accountByRelatedId.put(accountId, accountId);
		}
		relatedRecordIds.addAll(contactIds);
		accountByRelatedId.putAll(accountByContactId);
		if (Schema.sObjectType.Location.isAccessible()) {
			for (Schema.Location location : [SELECT Id, VL_Account__c FROM Location WHERE VL_Account__c IN :accountIds]) {
				relatedRecordIds.add(location.Id);
				accountByRelatedId.put(location.Id, location.VL_Account__c);
			}
		}
		for (Task task : [SELECT WhatId, WhoId FROM Task WHERE (WhatId IN :relatedRecordIds OR WhoId IN :contactIds) AND IsClosed = FALSE]) {
			blockedAccountIds.add(getActivityAccountId(task.WhatId, task.WhoId, accountByRelatedId));
		}
		for (Event eventRecord : [
			SELECT WhatId, WhoId
			FROM Event
			WHERE (WhatId IN :relatedRecordIds OR WhoId IN :contactIds) AND StartDateTime > :System.now()
		]) {
			blockedAccountIds.add(getActivityAccountId(eventRecord.WhatId, eventRecord.WhoId, accountByRelatedId));
		}
		return blockedAccountIds;
	}

	private static Id getActivityAccountId(Id whatId, Id whoId, Map<Id, Id> accountByRelatedId) {
		if (accountByRelatedId.containsKey(whatId)) {
			return accountByRelatedId.get(whatId);
		}
		return accountByRelatedId.get(whoId);
	}

	private static Set<Id> getAccountsWithoutActiveCommercialContacts(Set<Id> accountIds) {
		Set<Id> accountsWithActiveCommercialContact = new Set<Id>();
		if (Schema.sObjectType.Contact.isAccessible()) {
			for (Contact contact : [
				SELECT AccountId
				FROM Contact
				WHERE AccountId IN :accountIds AND VL_Active__c = TRUE AND VL_ContactType__c INCLUDES ('Comercial')
			]) {
				accountsWithActiveCommercialContact.add(contact.AccountId);
			}
		}
		Set<Id> blockedAccountIds = new Set<Id>();
		blockedAccountIds.addAll(accountIds);
		blockedAccountIds.removeAll(accountsWithActiveCommercialContact);
		return blockedAccountIds;
	}
}