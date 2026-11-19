/**
 * @name: VL_LeadConversionTriggerHelper
 * @version: 1.0
 * @creation date: 09/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description: Maps converted Lead customer type to the default Opportunity typology.
 */
@SuppressWarnings('PMD.ApexDoc')
public inherited sharing class VL_LeadConversionTriggerHelper {
	private static final String PRIVATE_TYPE = 'Privado';
	private static final String PUBLIC_TYPE = 'Administración Pública';
	private static final String NEW_CONTRACT_RECORD_TYPE = 'VL_NuevaContratacion';
	private static final String PUBLIC_TENDER_RECORD_TYPE = 'VL_LicitacionPublica';

	/**
	 * @name: assignOpportunityRecordTypes
	 * @version: 1.0
	 * @creation date: 09/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description: Assigns the default Opportunity Record Type for newly converted Leads.
	 * @param: leads Converted Lead records from the trigger context.
	 * @param: oldById Previous Lead values used to detect the conversion transition.
	 */
	public static void assignOpportunityRecordTypes(List<Lead> leads, Map<Id, Lead> oldById) {
		Map<Id, String> opportunityTypeById = new Map<Id, String>();
		Map<Id, Lead> convertedLeadByOpportunityId = new Map<Id, Lead>();
		for (Lead lead : leads) {
			if (lead.IsConverted != true || lead.ConvertedOpportunityId == null || oldById.get(lead.Id).IsConverted == true) {
				continue;
			}
			String recordTypeDeveloperName = getRecordTypeDeveloperName(lead.VL_Type__c);
			if (recordTypeDeveloperName != null) {
				opportunityTypeById.put(lead.ConvertedOpportunityId, recordTypeDeveloperName);
			}
			convertedLeadByOpportunityId.put(lead.ConvertedOpportunityId, lead);
		}

		if (convertedLeadByOpportunityId.isEmpty() || !Schema.sObjectType.Opportunity.isUpdateable()) {
			return;
		}

		Map<String, Schema.RecordTypeInfo> recordTypesByName = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
		List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
		for (Id opportunityId : convertedLeadByOpportunityId.keySet()) {
			Lead convertedLead = convertedLeadByOpportunityId.get(opportunityId);
			Opportunity opportunity = new Opportunity(Id = opportunityId);
			Schema.RecordTypeInfo recordTypeInfo = recordTypesByName.get(opportunityTypeById.get(opportunityId));
			if (recordTypeInfo != null) {
				opportunity.RecordTypeId = recordTypeInfo.getRecordTypeId();
			}
			opportunity.LeadSource = convertedLead.LeadSource;
			opportunity.VL_Origen__c = convertedLead.VL_Origen__c;
			opportunity.VL_ContractType__c = convertedLead.VL_ContractType__c;
			opportunitiesToUpdate.add(opportunity);
		}
		if (!opportunitiesToUpdate.isEmpty()) {
			Database.update(opportunitiesToUpdate, AccessLevel.USER_MODE);
		}
	}

	private static String getRecordTypeDeveloperName(String leadType) {
		if (leadType == PRIVATE_TYPE) {
			return NEW_CONTRACT_RECORD_TYPE;
		}
		if (leadType == PUBLIC_TYPE) {
			return PUBLIC_TENDER_RECORD_TYPE;
		}
		return null;
	}
}