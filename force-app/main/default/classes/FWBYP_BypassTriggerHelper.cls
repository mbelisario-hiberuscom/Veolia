/**
 * @name FWBYP_BypassTriggerHelper
 * @version 1.1
 * @creation date: 03/11/2025
 * @author: Jesus Piriz
 * @description Class to check if trigger is bypassed and manage bypass fields
 * @last_update: 17/04/2026 - Added field validation and documentation
 **/
public without sharing class FWBYP_BypassTriggerHelper {
	private static final String ALLTRIGGERS = 'FWBYP_AllTriggers__c';
	private static final String SETTING_OBJECT = 'FWBYP_Settings__c';

	/**
	 * @name checkBypass
	 * @version 1.1
	 * @creation date: 03/11/2025
	 * @author: Jesus Piriz
	 * @description Check if user has trigger bypassed. Validates that the field exists in FWBYP_Settings__c.
	 * If the field does not exist, it returns false and logs a warning.
	 * @param fieldPath Field API name (e.g., 'FWBYP_AllTriggers__c'). If empty, checks FWBYP_AllTriggers__c by default.
	 * @param userInfo User Id to resolve hierarchy setting
	 * @return Boolean - true if bypass is enabled, false otherwise or if field does not exist
	 */
	public static Boolean checkBypass(String fieldPath, Id userInfo) {
		FWBYP_Settings__c byPassSetting = FWBYP_Settings__c.getInstance(userInfo);
		if (Test.isRunningTest() && byPassSetting.get(ALLTRIGGERS) == null) {
			return false;
		}

		if (fieldPath != '') {
			String str = fieldPath;
			// Validate field existence
			Boolean fieldExists = fieldExistsInSetting(fieldPath);
			if (!fieldExists) {
				String errorMsg =
					'FWBYP_BypassTriggerHelper: Field "' +
					fieldPath +
					'" does not exist in ' +
					SETTING_OBJECT +
					'. ' +
					'Please add this field to FWBYP_Settings__c custom setting or use an existing field. ' +
					'See README for instructions on extending the framework.';
				System.debug(LoggingLevel.WARN, errorMsg);
				return false;
			}

			if (!(Boolean) byPassSetting.get(ALLTRIGGERS)) {
				return (Boolean) byPassSetting.get(str);
			} else {
				return true;
			}
		} else {
			return (Boolean) byPassSetting.get(ALLTRIGGERS);
		}
	}

	/**
	 * @name fieldExistsInSetting
	 * @version 1.0
	 * @creation date: 17/04/2026
	 * @author: Jesus Piriz
	 * @description Checks if a field exists in FWBYP_Settings__c custom setting
	 * @param fieldName Field API name (e.g., 'FWBYP_AccountTrigger__c')
	 * @return Boolean - true if field exists, false otherwise
	 */
	public static Boolean fieldExistsInSetting(String fieldName) {
		if (String.isBlank(fieldName)) {
			return false;
		}
		Map<String, Schema.SObjectField> fieldMap = FWBYP_Settings__c.getSObjectType().getDescribe().fields.getMap();
		return fieldMap.containsKey(fieldName);
	}

	/**
	 * @name getAvailableBypassFields
	 * @version 1.0
	 * @creation date: 17/04/2026
	 * @author: Jesus Piriz
	 * @description Returns a list of all checkbox fields available in FWBYP_Settings__c for bypass usage
	 * @return List<String> - List of field API names that are checkboxes and start with FWBYP_
	 */
	public static List<String> getAvailableBypassFields() {
		List<String> bypassFields = new List<String>();
		Map<String, Schema.SObjectField> fieldMap = FWBYP_Settings__c.getSObjectType().getDescribe().fields.getMap();

		for (String fieldName : fieldMap.keySet()) {
			Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
			// Include checkbox fields that start with fwbyp_
			if (field.getType() == Schema.DisplayType.Boolean && fieldName.toLowerCase().startsWith('fwbyp_')) {
				bypassFields.add(fieldName);
			}
		}
		return bypassFields;
	}
}