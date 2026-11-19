trigger VL_CollaborationTrigger on VL_Collaboration__c(before insert, before update) {
	FWTRG_TriggerFactory.checkAndExecute(VL_Collaboration__c.sObjectType.getDescribe().getName(), VL_CollaborationTriggerHandler.class);
}