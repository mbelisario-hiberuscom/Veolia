/**
 * @name VL_RecentlyViewedRecordsController
 * @version 1.0
 * @creation date 13/08/2026
 * @author Jesus Piriz
 * @description Controller for the generic recently viewed records component.
 */
public with sharing class VL_RecentlyViewedRecordsController {
	/**
	 * @name RecentlyViewedRecord
	 * @version 1.0
	 * @creation date 13/08/2026
	 * @author Jesus Piriz
	 * @description Recently viewed record payload.
	 */
	public class RecentlyViewedRecord {
		@AuraEnabled
		public Id recordId;
		@AuraEnabled
		public String recordName;
		@AuraEnabled
		public String objectApiName;
	}

	/**
	 * @name getRecentlyViewedRecords
	 * @creation date 13/08/2026
	 * @author Jesus Piriz
	 * @description Returns records most recently viewed by the current user.
	 * @param objectApiName API name of the object to query.
	 * @param recordLimit Maximum number of records to return.
	 * @return Recently viewed records ordered by LastViewedDate descending.
	 */
	@AuraEnabled(cacheable=true)
	public static List<RecentlyViewedRecord> getRecentlyViewedRecords(String objectApiName, Integer recordLimit) {
		if (String.isBlank(objectApiName)) {
			throw new AuraHandledException('Object API name is required.');
		}

		Integer safeLimit = recordLimit == null ? 5 : Math.max(1, Math.min(recordLimit, 50));
		Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
		Schema.SObjectType objectType = globalDescribe.get(objectApiName.trim());

		if (objectType == null || !objectType.getDescribe().isAccessible()) {
			throw new AuraHandledException('The configured object is not available.');
		}

		Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
		Map<String, Schema.SObjectField> objectFields = objectDescribe.fields.getMap();
		String nameField;
		if (objectFields.containsKey('Name') && objectFields.get('Name').getDescribe().isAccessible()) {
			nameField = 'Name';
		} else {
			for (String fieldApiName : objectFields.keySet()) {
				Schema.DescribeFieldResult fieldDescribe = objectFields.get(fieldApiName).getDescribe();
				if (fieldDescribe.isNameField() && fieldDescribe.isAccessible()) {
					nameField = fieldApiName;
					break;
				}
			}
		}
		String selectedNameField = String.isBlank(nameField) ? '' : ', ' + nameField;

		String soql =
			'SELECT Id, LastViewedDate' +
			selectedNameField +
			' FROM ' +
			String.escapeSingleQuotes(objectDescribe.getName()) +
			' WHERE LastViewedDate != NULL ORDER BY LastViewedDate DESC LIMIT ' +
			safeLimit;
		List<SObject> queriedRecords = Database.query(soql, AccessLevel.USER_MODE);
		List<RecentlyViewedRecord> recentlyViewedRecords = new List<RecentlyViewedRecord>();

		for (SObject record : queriedRecords) {
			RecentlyViewedRecord recordData = new RecentlyViewedRecord();
			recordData.recordId = (Id) record.get('Id');
			String displayName = String.isBlank(nameField) ? null : (String) record.get(nameField);
			recordData.recordName = String.isBlank(displayName) ? String.valueOf(recordData.recordId) : displayName;
			recordData.objectApiName = objectDescribe.getName();
			recentlyViewedRecords.add(recordData);
		}

		return recentlyViewedRecords;
	}
}