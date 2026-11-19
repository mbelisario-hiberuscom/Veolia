trigger VL_StandardLocationTrigger on Location(before insert, before update) {
	FWTRG_TriggerFactory.checkAndExecute(Location.sObjectType.getDescribe().getName(), VL_LocationHandler.class);
}