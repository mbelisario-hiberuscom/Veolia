/**
 * @name: VL_CollaborationTriggerHandler
 * @version: 1.0
 * @creation date: 09/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description: FWTRG handler for Collaboration primary-record validation.
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class VL_CollaborationTriggerHandler implements FWTRG_TriggerInterface {
	public void bulkBeforeInsert() {
		VL_CollaborationTriggerHelper.validatePrimaryCollaborations((List<VL_Collaboration__c>) Trigger.new, null);
	}

	public void bulkBeforeUpdate() {
		VL_CollaborationTriggerHelper.validatePrimaryCollaborations(
			(List<VL_Collaboration__c>) Trigger.new,
			(Map<Id, VL_Collaboration__c>) Trigger.oldMap
		);
	}

	public void bulkBeforeDelete() {
		return;
	}
	public void bulkAfterInsert() {
		return;
	}
	public void bulkAfterUpdate() {
		return;
	}
	public void bulkAfterDelete() {
		return;
	}
	public void bulkAfterUndelete() {
		return;
	}
	public void beforeInsert(SObject so) {
		return;
	}
	public void beforeUpdate(SObject oldSo, SObject so) {
		return;
	}
	public void beforeDelete(SObject so) {
		return;
	}
	public void afterInsert(SObject so) {
		return;
	}
	public void afterUpdate(SObject oldSo, SObject so) {
		return;
	}
	public void afterDelete(SObject so) {
		return;
	}
	public void afterUndelete(SObject so) {
		return;
	}
	public void finallyBeforeInsert() {
		return;
	}
	public void finallyBeforeUpdate() {
		return;
	}
	public void finallyBeforeDelete() {
		return;
	}
	public void finallyAfterInsert() {
		return;
	}
	public void finallyAfterUpdate() {
		return;
	}
	public void finallyAfterDelete() {
		return;
	}
	public void finallyAfterUndelete() {
		return;
	}
}