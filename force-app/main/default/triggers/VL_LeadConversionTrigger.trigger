trigger VL_LeadConversionTrigger on Lead(after update) {
	FWTRG_TriggerFactory.checkAndExecute(Lead.sObjectType.getDescribe().getName(), VL_LeadConversionTriggerHandler.class);
}