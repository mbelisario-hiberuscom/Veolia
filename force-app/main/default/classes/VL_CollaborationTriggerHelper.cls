/**
 * @name: VL_CollaborationTriggerHelper
 * @version: 1.0
 * @creation date: 09/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description: Enforces one primary collaboration per Opportunity in bulk-safe trigger contexts.
 */
@SuppressWarnings('PMD.ApexDoc')
public inherited sharing class VL_CollaborationTriggerHelper {
	private static final String PRIMARY_ERROR = 'Only one primary collaboration is allowed per Opportunity.';
	private static final String LEADER_ROLE = 'LIDER';
	private static final String COLLABORATOR_ROLE = 'COLABORADORA';
	private static final String LEADER_PRIMARY_ERROR = 'A leader collaboration must be the primary collaboration.';
	private static final String COLLABORATOR_PRIMARY_ERROR = 'A collaborator collaboration cannot be the primary collaboration.';

	public static void validatePrimaryCollaborations(List<VL_Collaboration__c> records, Map<Id, VL_Collaboration__c> oldById) {
		if (records == null || records.isEmpty()) {
			return;
		}

		validateRoles(records);
		Set<Id> opportunityIds = getOpportunityIds(records);
		Map<Id, Integer> primaryCountByOpportunity = countPrimaryRecords(records);

		if (opportunityIds.isEmpty()) {
			return;
		}

		Map<Id, Id> existingPrimaryByOpportunity = getExistingPrimaryByOpportunity(opportunityIds);
		removeCurrentPrimaries(existingPrimaryByOpportunity, oldById);
		addPrimaryErrors(records, primaryCountByOpportunity, existingPrimaryByOpportunity);
	}

	private static void validateRoles(List<VL_Collaboration__c> records) {
		for (VL_Collaboration__c collaboration : records) {
			if (String.isBlank(collaboration.VL_RolePicklist__c)) {
				continue;
			}
			if (collaboration.VL_RolePicklist__c == LEADER_ROLE && collaboration.VL_IsPrimary__c != true) {
				collaboration.addError(LEADER_PRIMARY_ERROR);
			} else if (collaboration.VL_RolePicklist__c == COLLABORATOR_ROLE && collaboration.VL_IsPrimary__c == true) {
				collaboration.addError(COLLABORATOR_PRIMARY_ERROR);
			}
		}
	}

	private static Set<Id> getOpportunityIds(List<VL_Collaboration__c> records) {
		Set<Id> opportunityIds = new Set<Id>();
		for (VL_Collaboration__c collaboration : records) {
			if (collaboration.VL_Opportunity__c != null && collaboration.VL_IsPrimary__c == true) {
				opportunityIds.add(collaboration.VL_Opportunity__c);
			}
		}
		return opportunityIds;
	}

	private static Map<Id, Integer> countPrimaryRecords(List<VL_Collaboration__c> records) {
		Map<Id, Integer> primaryCountByOpportunity = new Map<Id, Integer>();
		for (VL_Collaboration__c collaboration : records) {
			if (collaboration.VL_Opportunity__c == null || collaboration.VL_IsPrimary__c != true) {
				continue;
			}
			Integer currentCount = primaryCountByOpportunity.get(collaboration.VL_Opportunity__c);
			primaryCountByOpportunity.put(collaboration.VL_Opportunity__c, currentCount == null ? 1 : currentCount + 1);
		}
		return primaryCountByOpportunity;
	}

	private static Map<Id, Id> getExistingPrimaryByOpportunity(Set<Id> opportunityIds) {
		Map<Id, Id> existingPrimaryByOpportunity = new Map<Id, Id>();
		for (VL_Collaboration__c existingPrimary : [
			SELECT Id, VL_Opportunity__c
			FROM VL_Collaboration__c
			WHERE VL_Opportunity__c IN :opportunityIds AND VL_IsPrimary__c = TRUE
			WITH USER_MODE
		]) {
			existingPrimaryByOpportunity.put(existingPrimary.VL_Opportunity__c, existingPrimary.Id);
		}
		return existingPrimaryByOpportunity;
	}

	private static void addPrimaryErrors(
		List<VL_Collaboration__c> records,
		Map<Id, Integer> primaryCountByOpportunity,
		Map<Id, Id> existingPrimaryByOpportunity
	) {
		for (VL_Collaboration__c collaboration : records) {
			if (collaboration.VL_Opportunity__c == null || collaboration.VL_IsPrimary__c != true) {
				continue;
			}
			if (primaryCountByOpportunity.get(collaboration.VL_Opportunity__c) > 1) {
				collaboration.addError(PRIMARY_ERROR);
				continue;
			}
			Id existingPrimaryId = existingPrimaryByOpportunity.get(collaboration.VL_Opportunity__c);
			if (existingPrimaryId != null) {
				collaboration.addError(PRIMARY_ERROR);
			}
		}
	}

	private static void removeCurrentPrimaries(Map<Id, Id> existingPrimaryByOpportunity, Map<Id, VL_Collaboration__c> oldById) {
		if (oldById == null) {
			return;
		}
		for (VL_Collaboration__c oldCollaboration : oldById.values()) {
			if (
				oldCollaboration.VL_IsPrimary__c == true &&
				existingPrimaryByOpportunity.get(oldCollaboration.VL_Opportunity__c) == oldCollaboration.Id
			) {
				existingPrimaryByOpportunity.remove(oldCollaboration.VL_Opportunity__c);
			}
		}
	}
}