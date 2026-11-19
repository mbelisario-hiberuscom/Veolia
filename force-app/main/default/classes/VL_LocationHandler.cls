/**
 * @name: VL_LocationHandler
 * @version: 1.0
 * @creation date: 31/08/2026
 * @author: Alejandro Bueno Gimenez
 * @description Trigger handler for the standard Location object.
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class VL_LocationHandler implements FWTRG_TriggerInterface {
	public void bulkBeforeInsert() {
		VL_LocationHelper.beforeInsert(Trigger.new);
	}

	public void bulkBeforeUpdate() {
		VL_LocationHelper.beforeUpdate(Trigger.oldMap, Trigger.newMap);
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