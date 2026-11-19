/**
 * @name: FWTRG_TriggerFactory
 * @version: 1.0
 * @creation date: 05/11/2025
 * @author: Jesus Piriz
 * @description Factory class for Trigger Framework
 */
public with sharing class FWTRG_TriggerFactory {
	private static final String FWBYPASS_ALLTRIGGERS = 'FWBYP_AllTriggers__c';
	private static final String FWBYPASS_OBJECTTRIGGER = 'FWBYP_{0}BypassTrigger__c';

	public static Boolean disableAllTriggers = false;

	@TestVisible
	private static Set<String> disabledTriggers = new Set<String>();
	@TestVisible
	private static Boolean testingTriggerFramework = false;
	@TestVisible
	private static Boolean triggerIsAfter = false;
	@TestVisible
	private static Boolean triggerIsBefore = false;
	@TestVisible
	private static Boolean triggerIsDelete = false;
	@TestVisible
	private static Boolean triggerIsInsert = false;
	@TestVisible
	private static Boolean triggerIsUpdate = false;
	@TestVisible
	private static Boolean triggerIsUndelete = false;

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method to disable trigger for specific object
	 * @param obj String
	 * @return: N/A
	 */
	public static void disableTrigger(String obj) {
		disabledTriggers.add(obj.toLowerCase());
	}

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method to enable trigger for specific object
	 * @param obj String
	 * @return: N/A
	 */
	public static void enableTrigger(String obj) {
		disabledTriggers.remove(obj.toLowerCase());
	}

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method to check if trigger is disabled for specific object
	 * @param obj String
	 * @return Boolean
	 */
	public static Boolean isDisabled(String obj) {
		return disabledTriggers.contains(obj.toLowerCase());
	}

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method to check if trigger is disabled for specific object and execute the handler
	 * @param objName String
	 * @param handlerType Type
	 */
	public static void checkAndExecute(String objName, Type handlerType) {
		Object o = handlerType.newInstance();
		FWTRG_TriggerInterface handler = (FWTRG_TriggerInterface) o;

		if (disableAllTriggers || checkBypassTriggers(objName) || isDisabled(objName)) {
			return;
		}

		execute(handler);
	}

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method to check if trigger is bypassed for specific object
	 * @param objName String
	 * @return Boolean
	 */
	@TestVisible
	private static Boolean checkBypassTriggers(String objName) {
		Boolean result = false;
		if (objName.contains('__c')) {
			objName = objName.replace('__c', '');
		}

		if (objName.length() > 22) {
			objName = objName.substring(0, 22);
		}

		String str = String.format(FWBYPASS_OBJECTTRIGGER, new List<String>{ objName });

		try {
			result = FWBYP_BypassTriggerHelper.checkBypass(str, UserInfo.getUserId());
		} catch (Exception ex) {
			FWERR_ErrorHandler.insertError(ex, true);
		}
		return result;
	}

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method to execute the handler methods based on trigger context
	 * @param handler FWTRG_TriggerInterface
	 */
	@TestVisible
	private static void execute(FWTRG_TriggerInterface handler) {
		if (!testingTriggerFramework) {
			triggerIsAfter = Trigger.isAfter;
			triggerIsBefore = Trigger.isBefore;
			triggerIsDelete = Trigger.isDelete;
			triggerIsInsert = Trigger.isInsert;
			triggerIsUpdate = Trigger.isUpdate;
			triggerIsUndelete = Trigger.isUndelete;
		}
		if (triggerIsBefore == null && triggerIsAfter == null) {
			return;
		}

		if (triggerIsBefore) {
			if (triggerIsInsert) {
				handler.bulkBeforeInsert();
				if (Trigger.new != null) {
					for (SObject so : Trigger.new) {
						handler.beforeInsert(so);
					}
				}
				handler.finallyBeforeInsert();
			} else if (triggerIsUpdate) {
				handler.bulkBeforeUpdate();
				if (Trigger.old != null) {
					for (SObject so : Trigger.old) {
						handler.beforeUpdate(so, Trigger.newMap.get(so.Id));
					}
				}
				handler.finallyBeforeUpdate();
			} else if (triggerIsDelete) {
				handler.bulkBeforeDelete();
				if (Trigger.old != null) {
					for (SObject so : Trigger.old) {
						handler.beforeDelete(so);
					}
				}
				handler.finallyBeforeDelete();
			}
		} else {
			if (triggerIsInsert) {
				handler.bulkAfterInsert();
				if (Trigger.new != null) {
					for (SObject so : Trigger.new) {
						handler.afterInsert(so);
					}
				}
				handler.finallyAfterInsert();
			} else if (triggerIsUpdate) {
				handler.bulkAfterUpdate();
				if (Trigger.old != null) {
					for (SObject so : Trigger.old) {
						handler.afterUpdate(so, Trigger.newMap.get(so.Id));
					}
				}
				handler.finallyAfterUpdate();
			} else if (triggerIsDelete) {
				handler.bulkAfterDelete();
				if (Trigger.old != null) {
					for (SObject so : Trigger.old) {
						handler.afterDelete(so);
					}
				}
				handler.finallyAfterDelete();
			} else if (triggerIsUndelete) {
				handler.bulkAfterUndelete();
				if (Trigger.new != null) {
					for (SObject so : Trigger.new) {
						handler.afterUndelete(so);
					}
				}
				handler.finallyAfterUndelete();
			}
		}
	}

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method to check if field is changed
	 * @param newObj SObject
	 * @param oldObj SObject
	 * @param field Schema.sObjectField
	 * @return Boolean
	 */
	public static Boolean isFieldChanged(SObject newObj, SObject oldObj, Schema.sObjectField field) {
		return newObj.get(field) != oldObj.get(field);
	}
}