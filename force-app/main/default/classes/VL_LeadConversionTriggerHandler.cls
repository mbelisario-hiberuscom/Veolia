/**
 * @name: VL_LeadConversionTriggerHandler
 * @version: 1.0
 * @creation date: 09/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description: FWTRG handler for assigning Opportunity typology after Lead conversion.
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class VL_LeadConversionTriggerHandler implements FWTRG_TriggerInterface {
	public void bulkAfterUpdate() {
		VL_LeadConversionTriggerHelper.assignOpportunityRecordTypes((List<Lead>) Trigger.new, (Map<Id, Lead>) Trigger.oldMap);
	}

	public void bulkBeforeInsert() {
		return;
	}
	public void bulkBeforeUpdate() {
		return;
	}
	public void bulkBeforeDelete() {
		return;
	}
	public void bulkAfterInsert() {
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