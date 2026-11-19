/**
 * @name: VL_LocationHelper
 * @version: 1.0
 * @creation date: 31/08/2026
 * @author: Alejandro Bueno Gimenez
 * @description Business rules for the standard Location object.
 */
@SuppressWarnings('PMD.ApexDoc,PMD.CognitiveComplexity')
public inherited sharing class VL_LocationHelper {
	private static final String PRIMARY_ERROR = 'Only one active primary Location is allowed per Account.';

	public static void beforeInsert(List<SObject> locations) {
		if (locations == null || locations.isEmpty()) {
			return;
		}

		Set<Id> accountIds = collectAccountIds(locations);
		Set<Id> municipalityIds = collectMunicipalityIds(locations);
		applyDefaultKlm(locations, accountIds);
		applyIneCode(locations, municipalityIds);
		applyFirstPrimary(locations, accountIds);
	}

	public static void beforeUpdate(Map<Id, SObject> oldLocationsById, Map<Id, SObject> locationsById) {
		if (oldLocationsById == null || oldLocationsById.isEmpty() || locationsById == null || locationsById.isEmpty()) {
			return;
		}

		Set<Id> accountIds = new Set<Id>();
		Set<Id> municipalityIds = new Set<Id>();
		for (Id locationId : locationsById.keySet()) {
			SObject oldLocation = oldLocationsById.get(locationId);
			SObject location = locationsById.get(locationId);
			if (location.get('VL_Account__c') != null) {
				accountIds.add((Id) location.get('VL_Account__c'));
			}
			if (oldLocation.get('VL_Account__c') != null) {
				accountIds.add((Id) oldLocation.get('VL_Account__c'));
			}
			if (location.get('VL_Municipality__c') != null && location.get('VL_Municipality__c') != oldLocation.get('VL_Municipality__c')) {
				municipalityIds.add((Id) location.get('VL_Municipality__c'));
			}
			if (oldLocation.get('VL_Active__c') == true && location.get('VL_Active__c') == false) {
				location.put('VL_DeactivationDate__c', System.now());
				location.put('VL_DeactivatedBy__c', UserInfo.getUserId());
			}
		}

		applyDefaultKlm(locationsById.values(), accountIds);
		applyIneCode(locationsById.values(), municipalityIds);
		validatePrimaryUpdates(locationsById, accountIds);
	}

	private static Set<Id> collectAccountIds(List<SObject> locations) {
		Set<Id> accountIds = new Set<Id>();
		for (SObject location : locations) {
			if (location.get('VL_Account__c') != null) {
				accountIds.add((Id) location.get('VL_Account__c'));
			}
		}
		return accountIds;
	}

	private static Set<Id> collectMunicipalityIds(List<SObject> locations) {
		Set<Id> municipalityIds = new Set<Id>();
		for (SObject location : locations) {
			if (location.get('VL_Municipality__c') != null) {
				municipalityIds.add((Id) location.get('VL_Municipality__c'));
			}
		}
		return municipalityIds;
	}

	private static void applyDefaultKlm(List<SObject> locations, Set<Id> accountIds) {
		if (accountIds.isEmpty() || !Schema.sObjectType.Account.isAccessible()) {
			return;
		}

		Map<Id, Account> accountsById = new Map<Id, Account>(
			[
				SELECT Id, VL_KAM__c
				FROM Account
				WHERE Id IN :accountIds
			]
		);
		for (SObject location : locations) {
			Id accountId = (Id) location.get('VL_Account__c');
			if (location.get('VL_KLM__c') == null && accountsById.containsKey(accountId)) {
				location.put('VL_KLM__c', accountsById.get(accountId).VL_KAM__c);
			}
		}
	}

	private static void applyIneCode(List<SObject> locations, Set<Id> municipalityIds) {
		if (municipalityIds.isEmpty() || !Schema.sObjectType.VL_Municipality__c.isAccessible()) {
			return;
		}

		Map<Id, VL_Municipality__c> municipalitiesById = new Map<Id, VL_Municipality__c>(
			[
				SELECT Id, VL_Code_INE__c
				FROM VL_Municipality__c
				WHERE Id IN :municipalityIds
			]
		);
		for (SObject location : locations) {
			Id municipalityId = (Id) location.get('VL_Municipality__c');
			if (municipalitiesById.containsKey(municipalityId)) {
				location.put('VL_INECode__c', municipalitiesById.get(municipalityId).VL_Code_INE__c);
			}
		}
	}

	private static void applyFirstPrimary(List<SObject> locations, Set<Id> accountIds) {
		if (accountIds.isEmpty() || !Schema.sObjectType.Location.isAccessible()) {
			return;
		}

		Set<Id> accountsWithPrimary = new Set<Id>();
		for (SObject existingLocation : [
			SELECT Id, VL_Account__c
			FROM Location
			WHERE VL_Account__c IN :accountIds AND VL_IsPrimary__c = TRUE AND VL_Active__c = TRUE
		]) {
			accountsWithPrimary.add((Id) existingLocation.get('VL_Account__c'));
		}
		for (SObject location : locations) {
			Id accountId = (Id) location.get('VL_Account__c');
			if (accountId == null) {
				continue;
			}
			if (location.get('VL_IsPrimary__c') == true && accountsWithPrimary.contains(accountId)) {
				location.addError(PRIMARY_ERROR);
			} else if (!accountsWithPrimary.contains(accountId)) {
				location.put('VL_IsPrimary__c', true);
				accountsWithPrimary.add(accountId);
			}
		}
	}

	private static void validatePrimaryUpdates(Map<Id, SObject> locationsById, Set<Id> accountIds) {
		if (accountIds.isEmpty() || !Schema.sObjectType.Location.isAccessible()) {
			return;
		}

		Set<Id> accountsWithExistingPrimary = new Set<Id>();
		for (SObject existingLocation : [
			SELECT Id, VL_Account__c
			FROM Location
			WHERE VL_Account__c IN :accountIds AND VL_IsPrimary__c = TRUE AND VL_Active__c = TRUE
		]) {
			SObject incomingLocation = locationsById.get((Id) existingLocation.get('Id'));
			if (
				incomingLocation == null || (incomingLocation.get('VL_IsPrimary__c') == true && incomingLocation.get('VL_Active__c') == true)
			) {
				accountsWithExistingPrimary.add((Id) existingLocation.get('VL_Account__c'));
			}
		}
		Set<Id> accountsWithIncomingPrimary = new Set<Id>();
		for (SObject location : locationsById.values()) {
			Id accountId = (Id) location.get('VL_Account__c');
			if (accountId == null || location.get('VL_IsPrimary__c') != true || location.get('VL_Active__c') != true) {
				continue;
			}
			if (accountsWithExistingPrimary.contains(accountId) || accountsWithIncomingPrimary.contains(accountId)) {
				location.addError(PRIMARY_ERROR);
			} else {
				accountsWithIncomingPrimary.add(accountId);
			}
		}
	}
}