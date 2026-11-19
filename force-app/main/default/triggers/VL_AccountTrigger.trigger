trigger VL_AccountTrigger on Account(before insert, before update, after update) {
	FWTRG_TriggerFactory.checkAndExecute(Account.sObjectType.getDescribe().getName(), VL_AccountTriggerHandler.class);
}