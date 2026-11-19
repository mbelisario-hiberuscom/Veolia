/**
 * @name VL_GenericListViewSelectorController
 * @version 1.0
 * @creation date: 10/08/2026
 * @author: Jesus Piriz
 * @description Generic controller for list-view selection, field metadata and user preferences.
 **/
public with sharing class VL_GenericListViewSelectorController {
	private static final Integer DEFAULT_PAGE_SIZE = 20;
	private static final Set<Integer> VALID_PAGE_SIZES = new Set<Integer>{ 10, 20, 50, 100 };

	/**
	 * @name ListViewData
	 * @version 1.0
	 * @creation date: 10/08/2026
	 * @author: Jesus Piriz
	 * @description List view option exposed to the generic LWC.
	 */
	public class ListViewData {
		@AuraEnabled
		public Id id;
		@AuraEnabled
		public String sobjectType;
		@AuraEnabled
		public String developerName;
		@AuraEnabled
		public String label;
	}

	/**
	 * @name FieldData
	 * @version 1.0
	 * @creation date: 10/08/2026
	 * @author: Jesus Piriz
	 * @description Accessible field metadata exposed as a selectable column.
	 */
	public class FieldData {
		@AuraEnabled
		public String fieldApiName;
		@AuraEnabled
		public String label;
		@AuraEnabled
		public String type;
		@AuraEnabled
		public String relationshipName;
		@AuraEnabled
		public String customDataType;
		@AuraEnabled
		public Map<String, String> colorByValue;
	}

	/**
	 * @name CustomDataTypeConfiguration
	 * @version 1.0
	 * @creation date: 24/08/2026
	 * @author: Jesus Piriz
	 * @description Custom datatable type and its optional color configuration.
	 */
	private class CustomDataTypeConfiguration {
		private String customDataType;
		private Map<String, String> colorByValue = new Map<String, String>();
	}

	/**
	 * @name FieldValues
	 * @version 1.0
	 * @creation date: 10/08/2026
	 * @author: Jesus Piriz
	 * @description Additional field values grouped by record.
	 */
	public class FieldValues {
		@AuraEnabled
		public Id recordId;
		@AuraEnabled
		public Map<String, Object> values;
	}

	/**
	 * @name ListViewSettings
	 * @version 1.0
	 * @creation date: 10/08/2026
	 * @author: Jesus Piriz
	 * @description Generic per-user list-view and column preferences.
	 */
	public class ListViewSettings {
		@AuraEnabled
		public String selectedListViewApiName;
		@AuraEnabled
		public String columnConfiguration;
		@AuraEnabled
		public Integer pageSize;
	}

	/**
	 * @name getListViews
	 * @version 1.0
	 * @creation date: 10/08/2026
	 * @author: Jesus Piriz
	 * @description Returns list views available for the requested object.
	 * @param objectApiName Salesforce object API name.
	 * @return List<ListViewData> Available list views.
	 */
	@AuraEnabled(cacheable=true)
	public static List<ListViewData> getListViews(String objectApiName) {
		List<ListViewData> result = new List<ListViewData>();
		String normalizedObjectName = validateObjectName(objectApiName);
		if (normalizedObjectName == null) {
			return result;
		}

		for (ListView listView : [
			SELECT Id, SobjectType, DeveloperName, Name
			FROM ListView
			WHERE SobjectType = :normalizedObjectName
			WITH USER_MODE
		]) {
			ListViewData item = new ListViewData();
			item.id = listView.Id;
			item.sobjectType = listView.SobjectType;
			item.developerName = listView.DeveloperName;
			item.label = listView.Name;
			result.add(item);
		}
		return result;
	}

	/**
	 * @name getFields
	 * @version 1.0
	 * @creation date: 10/08/2026
	 * @author: Jesus Piriz
	 * @description Returns accessible fields for the requested object.
	 * @param objectApiName Salesforce object API name.
	 * @return List<FieldData> Accessible object fields.
	 */
	@AuraEnabled(cacheable=true)
	public static List<FieldData> getFields(String objectApiName) {
		List<FieldData> result = new List<FieldData>();
		Schema.SObjectType objectType = getObjectType(objectApiName);
		if (objectType == null || !objectType.getDescribe().isAccessible()) {
			return result;
		}

		String normalizedObjectName = objectType.getDescribe().getName();
		Map<String, CustomDataTypeConfiguration> customDataTypesByField = getCustomDataTypes(normalizedObjectName);
		Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
		for (String fieldName : fieldMap.keySet()) {
			Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
			if (!fieldDescribe.isAccessible()) {
				continue;
			}
			FieldData item = new FieldData();
			item.fieldApiName = fieldName;
			item.label = fieldDescribe.getLabel();
			item.type = String.valueOf(fieldDescribe.getType()).toLowerCase();
			item.relationshipName = fieldDescribe.getRelationshipName();
			CustomDataTypeConfiguration configuration = customDataTypesByField.get(fieldName.toLowerCase());
			item.customDataType = configuration?.customDataType;
			item.colorByValue = configuration?.colorByValue;
			result.add(item);
		}
		return result;
	}

	/**
	 * @name getCustomDataTypes
	 * @version 1.0
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Returns configured custom datatable types for the requested object.
	 * @param objectApiName Salesforce object API name.
	 * @return Map<String, String> Custom types keyed by field API name.
	 */
	private static Map<String, CustomDataTypeConfiguration> getCustomDataTypes(String objectApiName) {
		Map<String, CustomDataTypeConfiguration> result = new Map<String, CustomDataTypeConfiguration>();
		Map<Id, CustomDataTypeConfiguration> configurationsById = new Map<Id, CustomDataTypeConfiguration>();
		if (!Schema.sObjectType.VL_GenericDatatableType__c.isAccessible()) {
			return result;
		}

		for (VL_GenericDatatableType__c configuration : [
			SELECT Id, VL_FieldApiNameTxt__c, VL_CustomDataTypeSel__c
			FROM VL_GenericDatatableType__c
			WHERE VL_ObjectApiNameTxt__c = :objectApiName
			WITH USER_MODE
		]) {
			if (String.isNotBlank(configuration.VL_FieldApiNameTxt__c) && String.isNotBlank(configuration.VL_CustomDataTypeSel__c)) {
				CustomDataTypeConfiguration item = new CustomDataTypeConfiguration();
				item.customDataType = configuration.VL_CustomDataTypeSel__c;
				result.put(configuration.VL_FieldApiNameTxt__c.toLowerCase(), item);
				configurationsById.put(configuration.Id, item);
			}
		}
		if (result.isEmpty() || !Schema.sObjectType.VL_GenericDatatableColor__c.isAccessible()) {
			return result;
		}

		for (VL_GenericDatatableColor__c colorConfiguration : [
			SELECT VL_GenericDatatableTypeMDetail__c, VL_ValueTxt__c, VL_ColorSel__c
			FROM VL_GenericDatatableColor__c
			WHERE VL_GenericDatatableTypeMDetail__c IN :configurationsById.keySet()
			WITH USER_MODE
		]) {
			CustomDataTypeConfiguration item = configurationsById.get(colorConfiguration.VL_GenericDatatableTypeMDetail__c);
			if (item != null && String.isNotBlank(colorConfiguration.VL_ValueTxt__c) && String.isNotBlank(colorConfiguration.VL_ColorSel__c)) {
				item.colorByValue.put(colorConfiguration.VL_ValueTxt__c, colorConfiguration.VL_ColorSel__c);
			}
		}
		return result;
	}

	/**
	 * @name getFieldValues
	 * @version 1.0
	 * @creation date: 10/08/2026
	 * @author: Jesus Piriz
	 * @description Returns additional accessible values for selected records.
	 * @param objectApiName Salesforce object API name.
	 * @param recordIds Record IDs to query.
	 * @param fieldApiNames Field API names to query.
	 * @return List<FieldValues> Values grouped by record.
	 */
	@AuraEnabled(cacheable=true)
	public static List<FieldValues> getFieldValues(String objectApiName, List<String> recordIds, List<String> fieldApiNames) {
		List<FieldValues> result = new List<FieldValues>();
		Schema.SObjectType objectType = getObjectType(objectApiName);
		if (objectType == null || recordIds == null || recordIds.isEmpty() || fieldApiNames == null || fieldApiNames.isEmpty()) {
			return result;
		}

		Set<Id> ids = new Set<Id>();
		for (String recordId : recordIds) {
			try {
				ids.add(Id.valueOf(recordId));
			} catch (Exception ex) {
				continue;
			}
		}
		if (ids.isEmpty()) {
			return result;
		}

		Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
		Map<String, String> canonicalNames = new Map<String, String>();
		for (String fieldName : fieldMap.keySet()) {
			canonicalNames.put(fieldName.toLowerCase(), fieldName);
		}

		Map<String, Schema.DescribeFieldResult> references = new Map<String, Schema.DescribeFieldResult>();
		Set<String> picklistFields = new Set<String>();
		Set<String> validNames = new Set<String>{ 'Id' };
		for (String requestedName : fieldApiNames) {
			String fieldName = canonicalNames.get(requestedName == null ? '' : requestedName.toLowerCase());
			if (fieldName == null || validNames.contains(fieldName)) {
				continue;
			}
			Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
			if (!fieldDescribe.isAccessible()) {
				continue;
			}
			validNames.add(fieldName);
			if (fieldDescribe.getType() == Schema.DisplayType.PICKLIST || fieldDescribe.getType() == Schema.DisplayType.MULTIPICKLIST) {
				picklistFields.add(fieldName);
			}
			if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE && String.isNotBlank(fieldDescribe.getRelationshipName())) {
				references.put(fieldName, fieldDescribe);
			}
		}
		if (validNames.size() == 1) {
			for (Id recordId : ids) {
				FieldValues item = new FieldValues();
				item.recordId = recordId;
				item.values = new Map<String, Object>();
				result.add(item);
			}
			return result;
		}

		Set<String> queryFields = new Set<String>{ 'Id' };
		for (String fieldName : validNames) {
			if (!fieldName.equalsIgnoreCase('Id')) {
				queryFields.add(picklistFields.contains(fieldName) ? 'toLabel(' + fieldName + ')' : fieldName);
			}
		}
		for (Schema.DescribeFieldResult reference : references.values()) {
			queryFields.add(reference.getRelationshipName() + '.Name');
		}
		List<String> orderedFields = new List<String>(queryFields);
		orderedFields.sort();
		String query =
			'SELECT ' +
			String.join(orderedFields, ', ') +
			' FROM ' +
			objectType.getDescribe().getName() +
			' WHERE Id IN :ids WITH USER_MODE';
		for (SObject record : Database.query(query)) {
			// NOPMD: object and fields are validated from describe metadata.
			FieldValues item = new FieldValues();
			item.recordId = (Id) record.get('Id');
			item.values = new Map<String, Object>();
			for (String fieldName : validNames) {
				if (fieldName == 'Id') {
					continue;
				}
				if (references.containsKey(fieldName)) {
					Schema.DescribeFieldResult reference = references.get(fieldName);
					SObject relatedRecord = record.getSObject(reference.getRelationshipName());
					item.values.put(fieldName, relatedRecord == null ? null : relatedRecord.get('Name'));
					item.values.put(fieldName + '__url', record.get(fieldName));
				} else {
					item.values.put(fieldName, record.get(fieldName));
				}
			}
			result.add(item);
		}
		return result;
	}

	/**
	 * @name getSettings
	 * @version 1.0
	 * @creation date: 10/08/2026
	 * @author: Jesus Piriz
	 * @description Returns generic preferences for the requested object.
	 * @param objectApiName Salesforce object API name.
	 * @return ListViewSettings Stored preferences.
	 */
	@AuraEnabled(cacheable=true)
	public static ListViewSettings getSettings(String objectApiName) {
		ListViewSettings result = new ListViewSettings();
		String normalizedObjectName = validateObjectName(objectApiName);
		if (normalizedObjectName == null) {
			return result;
		}

		List<VL_UserListViewPreference__c> preferences = [
			SELECT
				Id,
				VL_ListViewApiNameTxt__c,
				VL_IsSelected__c,
				VL_PageSizeNum__c,
				(
					SELECT VL_FieldApiNameTxt__c, VL_PositionNum__c, VL_IsVisible__c
					FROM PreferenceColumns__r
					ORDER BY VL_PositionNum__c ASC
				)
			FROM VL_UserListViewPreference__c
			WHERE VL_UserLookup__c = :UserInfo.getUserId() AND VL_ObjectApiNameTxt__c = :normalizedObjectName
			WITH USER_MODE
		];
		List<String> configurations = new List<String>();
		for (VL_UserListViewPreference__c preference : preferences) {
			String configuration = serializeColumnRows(preference.PreferenceColumns__r);
			if (String.isNotBlank(configuration)) {
				configurations.add(preference.VL_ListViewApiNameTxt__c + '~' + configuration);
			}
			if (preference.VL_IsSelected__c) {
				result.selectedListViewApiName = preference.VL_ListViewApiNameTxt__c;
				result.pageSize = preference.VL_PageSizeNum__c == null
					? DEFAULT_PAGE_SIZE
					: Integer.valueOf(String.valueOf(preference.VL_PageSizeNum__c));
			}
		}
		result.columnConfiguration = String.join(configurations, '|');
		return result;
	}

	/**
	 * @name saveSettings
	 * @version 1.0
	 * @creation date: 10/08/2026
	 * @author: Jesus Piriz
	 * @description Saves generic preferences for the requested object.
	 * @param objectApiName Salesforce object API name.
	 * @param selectedListViewApiName Selected list view developer name.
	 * @param columnConfiguration Serialized column configuration.
	 * @param pageSize Number of rows displayed per page.
	 */
	@AuraEnabled
	public static void saveSettings(String objectApiName, String selectedListViewApiName, String columnConfiguration, Integer pageSize) {
		try {
			String normalizedObjectName = validateObjectName(objectApiName);
			if (normalizedObjectName == null) {
				throw new AuraHandledException('Invalid object API name.');
			}
			Integer normalizedPageSize = normalizePageSize(pageSize);
			Map<String, String> configurations = parseSettings(columnConfiguration == null ? '' : columnConfiguration);
			List<VL_UserListViewPreference__c> existingPreferences = [
				SELECT Id, VL_ConfigurationKeyTxt__c, VL_ListViewApiNameTxt__c, VL_IsSelected__c, VL_PageSizeNum__c
				FROM VL_UserListViewPreference__c
				WHERE VL_UserLookup__c = :UserInfo.getUserId() AND VL_ObjectApiNameTxt__c = :normalizedObjectName
				WITH USER_MODE
			];
			Map<String, VL_UserListViewPreference__c> preferencesByKey = new Map<String, VL_UserListViewPreference__c>();
			for (VL_UserListViewPreference__c preference : existingPreferences) {
				preferencesByKey.put(preference.VL_ConfigurationKeyTxt__c, preference);
				preference.VL_IsSelected__c = preference.VL_ListViewApiNameTxt__c == selectedListViewApiName;
				preference.VL_PageSizeNum__c = normalizedPageSize;
			}

			List<VL_UserListViewPreference__c> preferencesToUpsert = new List<VL_UserListViewPreference__c>();
			for (String listViewApiName : configurations.keySet()) {
				String key = buildConfigurationKey(normalizedObjectName, listViewApiName);
				VL_UserListViewPreference__c preference = preferencesByKey.get(key);
				if (preference == null) {
					preference = new VL_UserListViewPreference__c(
						VL_UserLookup__c = UserInfo.getUserId(),
						VL_ObjectApiNameTxt__c = normalizedObjectName,
						VL_ListViewApiNameTxt__c = listViewApiName,
						VL_ConfigurationKeyTxt__c = key,
						VL_PageSizeNum__c = normalizedPageSize
					);
				}
				preference.VL_IsSelected__c = listViewApiName == selectedListViewApiName;
				preference.VL_PageSizeNum__c = normalizedPageSize;
				preferencesToUpsert.add(preference);
			}

			if (selectedListViewApiName != null && !configurations.containsKey(selectedListViewApiName)) {
				String key = buildConfigurationKey(normalizedObjectName, selectedListViewApiName);
				VL_UserListViewPreference__c preference = preferencesByKey.get(key);
				if (preference == null) {
					preference = new VL_UserListViewPreference__c(
						VL_UserLookup__c = UserInfo.getUserId(),
						VL_ObjectApiNameTxt__c = normalizedObjectName,
						VL_ListViewApiNameTxt__c = selectedListViewApiName,
						VL_ConfigurationKeyTxt__c = key,
						VL_PageSizeNum__c = normalizedPageSize
					);
				}
				preference.VL_IsSelected__c = true;
				preference.VL_PageSizeNum__c = normalizedPageSize;
				preferencesToUpsert.add(preference);
			}

			if (!existingPreferences.isEmpty()) {
				Database.update(existingPreferences, AccessLevel.USER_MODE);
			}
			if (!preferencesToUpsert.isEmpty()) {
				Database.upsert(preferencesToUpsert, AccessLevel.USER_MODE);
			}

			Set<Id> preferenceIds = new Map<Id, VL_UserListViewPreference__c>(preferencesToUpsert).keySet();
			if (!preferenceIds.isEmpty()) {
				List<VL_UserListViewPreferenceColumn__c> existingColumns = [
					SELECT Id
					FROM VL_UserListViewPreferenceColumn__c
					WHERE VL_UserListViewPreferenceMDetail__c IN :preferenceIds
					WITH USER_MODE
				];
				if (!existingColumns.isEmpty()) {
					Database.delete(existingColumns, false);
				}
			}

			List<VL_UserListViewPreferenceColumn__c> columnsToInsert = new List<VL_UserListViewPreferenceColumn__c>();
			for (VL_UserListViewPreference__c preference : preferencesToUpsert) {
				String configuration = configurations.get(preference.VL_ListViewApiNameTxt__c);
				columnsToInsert.addAll(buildColumnPreferences(preference.Id, configuration, normalizedObjectName));
			}
			if (!columnsToInsert.isEmpty()) {
				Database.insert(columnsToInsert, AccessLevel.USER_MODE);
			}
		} catch (Exception ex) {
			FWERR_ErrorHandler.insertError(ex, true);
		}
	}

	/**
	 * @name getObjectType
	 * @version 1.0
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Resolves an object API name against the global describe map.
	 * @param objectApiName Salesforce object API name.
	 * @return Schema.SObjectType Resolved object type, or null when invalid.
	 */
	private static Schema.SObjectType getObjectType(String objectApiName) {
		if (String.isBlank(objectApiName)) {
			return null;
		}
		return Schema.getGlobalDescribe().get(objectApiName.trim());
	}

	/**
	 * @name validateObjectName
	 * @version 1.0
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Validates and canonicalizes an object API name.
	 * @param objectApiName Salesforce object API name.
	 * @return String Canonical object API name, or null when invalid.
	 */
	private static String validateObjectName(String objectApiName) {
		Schema.SObjectType objectType = getObjectType(objectApiName);
		return objectType == null ? null : objectType.getDescribe().getName();
	}

	/**
	 * @name normalizePageSize
	 * @version 1.0
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Restricts a requested page size to the supported values.
	 * @param pageSize Requested number of rows per page.
	 * @return Integer Supported page size, or the default value.
	 */
	private static Integer normalizePageSize(Integer pageSize) {
		return VALID_PAGE_SIZES.contains(pageSize) ? pageSize : DEFAULT_PAGE_SIZE;
	}

	/**
	 * @name parseSettings
	 * @version 1.0
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Parses serialized list-view column configurations.
	 * @param serialized Serialized list-view configurations.
	 * @return Map<String, String> Configurations keyed by list view API name.
	 */
	private static Map<String, String> parseSettings(String serialized) {
		Map<String, String> result = new Map<String, String>();
		for (String item : serialized.split('\\|')) {
			Integer separator = item.indexOf('~');
			if (separator > 0) {
				result.put(item.substring(0, separator), item.substring(separator + 1));
			}
		}
		return result;
	}

	/**
	 * @name buildConfigurationKey
	 * @version 1.0
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Builds the stable key used to identify a user list-view preference.
	 * @param objectApiName Salesforce object API name.
	 * @param listViewApiName List view API name.
	 * @return String Stable preference key.
	 */
	private static String buildConfigurationKey(String objectApiName, String listViewApiName) {
		return UserInfo.getUserId() + '|' + objectApiName + '|' + listViewApiName;
	}

	/**
	 * @name serializeColumnRows
	 * @version 1.0
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Serializes persisted column preference rows in display order.
	 * @param columns Persisted column preference rows.
	 * @return String Versioned column configuration, or an empty string.
	 */
	private static String serializeColumnRows(List<VL_UserListViewPreferenceColumn__c> columns) {
		List<String> serializedColumns = new List<String>();
		for (VL_UserListViewPreferenceColumn__c column : columns) {
			serializedColumns.add((column.VL_IsVisible__c ? '' : '!') + column.VL_FieldApiNameTxt__c);
		}
		return serializedColumns.isEmpty() ? '' : 'v2:' + String.join(serializedColumns, ',');
	}

	/**
	 * @name buildColumnPreferences
	 * @version 1.0
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Converts serialized columns into persisted preference records.
	 * @param preferenceId Parent preference ID.
	 * @param configuration Serialized column configuration.
	 * @param objectApiName Salesforce object API name.
	 * @return List<VL_UserListViewPreferenceColumn__c> Valid column preference records.
	 */
	private static List<VL_UserListViewPreferenceColumn__c> buildColumnPreferences(
		Id preferenceId,
		String configuration,
		String objectApiName
	) {
		List<VL_UserListViewPreferenceColumn__c> result = new List<VL_UserListViewPreferenceColumn__c>();
		if (String.isBlank(configuration)) {
			return result;
		}
		Map<String, Schema.SObjectField> fieldMap = getObjectType(objectApiName).getDescribe().fields.getMap();
		String serializedFields = configuration.startsWith('v2:') ? configuration.substring(3) : configuration;
		List<String> fields = serializedFields.split(',');
		Set<String> addedFields = new Set<String>();
		for (Integer position = 0; position < fields.size(); position++) {
			String configuredField = fields[position];
			Boolean visible = !configuredField.startsWith('!');
			String fieldApiName = visible ? configuredField : configuredField.substring(1);
			String canonicalFieldName = findCanonicalFieldName(fieldMap, fieldApiName);
			if (canonicalFieldName == null || addedFields.contains(canonicalFieldName)) {
				continue;
			}
			Schema.DescribeFieldResult fieldDescribe = fieldMap.get(canonicalFieldName).getDescribe();
			if (!fieldDescribe.isAccessible()) {
				continue;
			}
			addedFields.add(canonicalFieldName);
			result.add(
				new VL_UserListViewPreferenceColumn__c(
					VL_UserListViewPreferenceMDetail__c = preferenceId,
					VL_FieldApiNameTxt__c = canonicalFieldName,
					VL_PositionNum__c = position,
					VL_IsVisible__c = visible
				)
			);
		}
		return result;
	}

	/**
	 * @name findCanonicalFieldName
	 * @version 1.0
	 * @creation date: 12/08/2026
	 * @author: Jesus Piriz
	 * @description Finds a field API name without depending on input capitalization.
	 * @param fieldMap Object field describe map.
	 * @param requestedFieldName Requested field API name.
	 * @return String Canonical field API name, or null when not found.
	 */
	private static String findCanonicalFieldName(Map<String, Schema.SObjectField> fieldMap, String requestedFieldName) {
		for (String fieldName : fieldMap.keySet()) {
			if (fieldName.equalsIgnoreCase(requestedFieldName)) {
				return fieldName;
			}
		}
		return null;
	}
}