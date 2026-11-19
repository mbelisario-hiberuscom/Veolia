/**
 * @name VL_SalesforceRecordResolver
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description Resolves a set of record Ids to their sObject type API name and display Name.
 *              Groups Ids by sObjectType and issues a single dynamic SOQL per type.
 */
public inherited sharing class VL_SalesforceRecordResolver {
	/**
	 * @name resolve
	 * @creation date: 27/08/2026
	 * @author: Jesus Piriz
	 * @description Resolves each Id in the set to a VL_ResolvedRecord containing objectApiName and recordName.
	 *              Issues one query per distinct sObject type; bulk-safe for 200+ mixed Ids.
	 * @param recordIds Set of Salesforce record Ids to resolve.
	 * @return Map<Id, VL_ResolvedRecord> keyed by record Id.
	 * @throws VL_GoogleDriveException TERMINAL_CONFIG when an Id resolves to an unsupported type.
	 */
	public static Map<Id, VL_ResolvedRecord> resolve(Set<Id> recordIds) {
		if (recordIds == null || recordIds.isEmpty()) {
			return new Map<Id, VL_ResolvedRecord>();
		}
		Map<Schema.SObjectType, Set<Id>> idsByType = groupByType(recordIds);
		Map<Id, VL_ResolvedRecord> result = new Map<Id, VL_ResolvedRecord>();
		for (Schema.SObjectType sType : idsByType.keySet()) {
			Set<Id> typeIds = idsByType.get(sType);
			String typeName = sType.getDescribe().getName();
			queryAndMap(typeName, typeIds, result);
		}
		return result;
	}

	// ── Private helpers ─────────────────────────────────────────────────────────

	private static Map<Schema.SObjectType, Set<Id>> groupByType(Set<Id> recordIds) {
		Map<Schema.SObjectType, Set<Id>> grouped = new Map<Schema.SObjectType, Set<Id>>();
		for (Id rid : recordIds) {
			Schema.SObjectType sType = rid.getSObjectType();
			if (!grouped.containsKey(sType)) {
				grouped.put(sType, new Set<Id>());
			}
			grouped.get(sType).add(rid);
		}
		return grouped;
	}

	private static void queryAndMap(String typeName, Set<Id> ids, Map<Id, VL_ResolvedRecord> result) {
		try {
			String soql = 'SELECT Id, Name FROM ' + typeName + ' WHERE Id IN :ids WITH USER_MODE';
			List<SObject> records = Database.query(soql);
			for (SObject rec : records) {
				result.put((Id) rec.get('Id'), new VL_ResolvedRecord(typeName, (String) rec.get('Name')));
			}
		} catch (Exception ex) {
			throw new VL_GoogleDriveException(
				'Record resolution failed for type ' + typeName + ': ' + ex.getMessage(),
				VL_GoogleDriveException.ErrorCategory.TERMINAL_CONFIG
			);
		}
	}
}