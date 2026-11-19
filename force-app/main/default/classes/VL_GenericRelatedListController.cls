/**
 * @name VL_GenericRelatedListController
 * @version 1.0
 * @creation date: 13/08/2026
 * @author: Jesus Piriz
 * @description Controller for the reusable generic related list LWC.
 **/
public with sharing class VL_GenericRelatedListController {
	private static final Integer DEFAULT_LIMIT = 200;
	private static final Integer MAX_LIMIT = 50000;
	@TestVisible
	private static Map<String, List<String>> fieldSetFieldsByName;

	/**
	 * @name RelatedField
	 * @version 1.0
	 * @creation date: 13/08/2026
	 * @author: Jesus Piriz
	 * @description Field set member metadata exposed to the generic related list.
	 */
	public class RelatedField {
		@AuraEnabled
		public String fieldName;
		@AuraEnabled
		public String label;
		@AuraEnabled
		public String dataType;
		@AuraEnabled
		public Boolean isLookup;
	}

	/**
	 * @name RelatedRecord
	 * @version 1.0
	 * @creation date: 13/08/2026
	 * @author: Jesus Piriz
	 * @description Related record values prepared for the generic datatable.
	 */
	public class RelatedRecord {
		@AuraEnabled
		public Id recordId;
		@AuraEnabled
		public Map<String, Object> values;
	}

	/**
	 * @name RelatedListResponse
	 * @version 1.0
	 * @creation date: 13/08/2026
	 * @author: Jesus Piriz
	 * @description Field set metadata and records returned by the related list query.
	 */
	public class RelatedListResponse {
		@AuraEnabled
		public List<RelatedField> fields;
		@AuraEnabled
		public List<RelatedRecord> records;
	}

	/**
	 * @name getRelatedRecords
	 * @creation date: 13/08/2026
	 * @author: Jesus Piriz
	 * @description Returns accessible child records related to the current parent record.
	 * @param recordId Current parent record Id.
	 * @param relatedObjectApiName Child object API name.
	 * @param fieldSet Field set API name on the child object.
	 * @param whereClause SOQL condition. It may bind the current record with :recordId.
	 * @param orderBy Optional SOQL order expression configured by the component consumer.
	 * @param limitSize Maximum number of records to return.
	 * @return RelatedListResponse Field set metadata and child records.
	 */
	@AuraEnabled(cacheable=true)
	public static RelatedListResponse getRelatedRecords(
		Id recordId,
		String relatedObjectApiName,
		String fieldSet,
		String whereClause,
		String orderBy,
		Integer limitSize
	) {
		RelatedListResponse response = new RelatedListResponse();
		response.fields = new List<RelatedField>();
		response.records = new List<RelatedRecord>();
		if (String.isBlank(relatedObjectApiName) || String.isBlank(fieldSet)) {
			return response;
		}

		Schema.SObjectType childType = Schema.getGlobalDescribe().get(relatedObjectApiName.trim());
		if (childType == null || !childType.getDescribe().isAccessible()) {
			return response;
		}

		Schema.DescribeSObjectResult childDescribe = childType.getDescribe();
		Map<String, Schema.SObjectField> fieldMap = childType.getDescribe().fields.getMap();

		Set<String> selectedFields = new Set<String>{ 'Id' };
		Map<String, Schema.DescribeFieldResult> referenceFields = new Map<String, Schema.DescribeFieldResult>();
		List<String> configuredFieldNames = getFieldSetFieldNames(childDescribe, fieldSet);
		if (configuredFieldNames == null) {
			return response;
		}
		for (String fieldName : configuredFieldNames) {
			if (fieldName.contains('.') || !fieldMap.containsKey(fieldName)) {
				continue;
			}
			Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
			if (!fieldDescribe.isAccessible() || selectedFields.contains(fieldName)) {
				continue;
			}
			selectedFields.add(fieldName);
			RelatedField relatedField = new RelatedField();
			relatedField.fieldName = fieldName;
			relatedField.label = fieldDescribe.getLabel();
			relatedField.dataType = String.valueOf(fieldDescribe.getType()).toLowerCase();
			relatedField.isLookup = fieldDescribe.getType() == Schema.DisplayType.REFERENCE;
			response.fields.add(relatedField);
			if (relatedField.isLookup && String.isNotBlank(fieldDescribe.getRelationshipName())) {
				referenceFields.put(fieldName, fieldDescribe);
			}
		}
		if (response.fields.isEmpty()) {
			return response;
		}

		Set<String> queryFields = new Set<String>(selectedFields);
		for (Schema.DescribeFieldResult referenceDescribe : referenceFields.values()) {
			queryFields.add(referenceDescribe.getRelationshipName() + '.Name');
		}
		List<String> orderedFields = new List<String>(queryFields);
		orderedFields.sort();
		Integer safeLimit = limitSize == null || limitSize < 1 ? DEFAULT_LIMIT : Math.min(limitSize, MAX_LIMIT);
		String query =
			'SELECT ' +
			String.join(orderedFields, ', ') +
			' FROM ' +
			childDescribe.getName() +
			(String.isBlank(whereClause) ? '' : ' WHERE ' + whereClause) +
			(String.isBlank(orderBy) ? ' ORDER BY CreatedDate DESC' : ' ORDER BY ' + orderBy) +
			' LIMIT :safeLimit';

		for (SObject record : Database.query(query, AccessLevel.USER_MODE)) {
			// NOPMD: field set and query clauses are validated configuration.
			RelatedRecord item = new RelatedRecord();
			item.recordId = (Id) record.get('Id');
			item.values = new Map<String, Object>();
			for (String fieldName : selectedFields) {
				if (fieldName == 'Id') {
					continue;
				}
				if (referenceFields.containsKey(fieldName)) {
					Schema.DescribeFieldResult referenceDescribe = referenceFields.get(fieldName);
					SObject relatedRecord = record.getSObject(referenceDescribe.getRelationshipName());
					item.values.put(fieldName, relatedRecord == null ? null : relatedRecord.get('Name'));
					item.values.put(fieldName + 'Url', record.get(fieldName));
				} else {
					item.values.put(fieldName, record.get(fieldName));
				}
			}
			response.records.add(item);
		}
		return response;
	}

	private static List<String> getFieldSetFieldNames(Schema.DescribeSObjectResult childDescribe, String fieldSet) {
		if (Test.isRunningTest() && fieldSetFieldsByName != null && fieldSetFieldsByName.containsKey(fieldSet)) {
			return fieldSetFieldsByName.get(fieldSet);
		}
		Schema.FieldSet configuredFieldSet = childDescribe.fieldSets.getMap().get(fieldSet);
		if (configuredFieldSet == null) {
			return null;
		}
		List<String> fieldNames = new List<String>();
		for (Schema.FieldSetMember member : configuredFieldSet.getFields()) {
			fieldNames.add(String.valueOf(member.getFieldPath()));
		}
		return fieldNames;
	}
}