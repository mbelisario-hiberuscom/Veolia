/**
 * @name: VL_AccountTriggerHandler
 * @version: 1.0
 * @creation date: 01/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Trigger handler for Account edit validations and related-record integrity.
 */
public with sharing class VL_AccountTriggerHandler implements FWTRG_TriggerInterface {
	/**
	 * @name: bulkBeforeInsert
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Validates fiscal number format and duplicates before Account insertion.
	 */
	public void bulkBeforeInsert() {
		VL_AccountHelper.validateFiscalNumbersFormat((List<Account>) Trigger.new);
		VL_AccountHelper.validateFiscalNumbers((List<Account>) Trigger.new, null);
	}

	/**
	 * @name: bulkBeforeUpdate
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Validates fiscal number format and changed duplicate values before Account update.
	 */
	public void bulkBeforeUpdate() {
		VL_AccountHelper.validateFiscalNumbersFormat((List<Account>) Trigger.new);
		VL_AccountHelper.validateFiscalNumbers((List<Account>) Trigger.new, (Map<Id, Account>) Trigger.oldMap);
		// VL_AccountRelationshipHelper.validateCommercialContactExists(Trigger.newMap.keySet());
		// VL_AccountRelationshipHelper.validateAccountDeactivation((Map<Id, Account>) Trigger.oldMap, (Map<Id, Account>) Trigger.newMap);
	}

	/**
	 * @name: bulkAfterUpdate
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Synchronizes the KLM on related Locations after an Account update.
	 */
	public void bulkAfterUpdate() {
		VL_AccountRelationshipHelper.synchronizeLocationsKlm((Map<Id, Account>) Trigger.oldMap, (Map<Id, Account>) Trigger.newMap);
	}

	/**
	 * @name: bulkBeforeDelete
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the required framework callback before Account deletion.
	 */
	public void bulkBeforeDelete() {
		return;
	}

	/**
	 * @name: bulkAfterInsert
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the required framework callback after Account insertion.
	 */
	public void bulkAfterInsert() {
		return;
	}

	/**
	 * @name: bulkAfterDelete
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the required framework callback after Account deletion.
	 */
	public void bulkAfterDelete() {
		return;
	}

	/**
	 * @name: bulkAfterUndelete
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the required framework callback after Account undelete.
	 */
	public void bulkAfterUndelete() {
		return;
	}

	/**
	 * @name: beforeInsert
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the per-record framework callback before Account insertion.
	 * @param so Account record being inserted.
	 */
	public void beforeInsert(SObject so) {
		return;
	}

	/**
	 * @name: beforeUpdate
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the per-record framework callback before Account update.
	 * @param oldSo Account record before the update.
	 * @param so Account record after the update.
	 */
	public void beforeUpdate(SObject oldSo, SObject so) {
		return;
	}

	/**
	 * @name: beforeDelete
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the per-record framework callback before Account deletion.
	 * @param so Account record being deleted.
	 */
	public void beforeDelete(SObject so) {
		return;
	}

	/**
	 * @name: afterInsert
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the per-record framework callback after Account insertion.
	 * @param so Account record that was inserted.
	 */
	public void afterInsert(SObject so) {
		return;
	}

	/**
	 * @name: afterUpdate
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the per-record framework callback after Account update.
	 * @param oldSo Account record before the update.
	 * @param so Account record after the update.
	 */
	public void afterUpdate(SObject oldSo, SObject so) {
		return;
	}

	/**
	 * @name: afterDelete
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the per-record framework callback after Account deletion.
	 * @param so Account record that was deleted.
	 */
	public void afterDelete(SObject so) {
		return;
	}

	/**
	 * @name: afterUndelete
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the per-record framework callback after Account undelete.
	 * @param so Account record that was restored.
	 */
	public void afterUndelete(SObject so) {
		return;
	}

	/**
	 * @name: finallyBeforeInsert
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the final framework callback before Account insertion.
	 */
	public void finallyBeforeInsert() {
		return;
	}

	/**
	 * @name: finallyBeforeUpdate
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the final framework callback before Account update.
	 */
	public void finallyBeforeUpdate() {
		return;
	}

	/**
	 * @name: finallyBeforeDelete
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the final framework callback before Account deletion.
	 */
	public void finallyBeforeDelete() {
		return;
	}

	/**
	 * @name: finallyAfterInsert
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the final framework callback after Account insertion.
	 */
	public void finallyAfterInsert() {
		return;
	}

	/**
	 * @name: finallyAfterUpdate
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the final framework callback after Account update.
	 */
	public void finallyAfterUpdate() {
		return;
	}

	/**
	 * @name: finallyAfterDelete
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the final framework callback after Account deletion.
	 */
	public void finallyAfterDelete() {
		return;
	}

	/**
	 * @name: finallyAfterUndelete
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Provides the final framework callback after Account undelete.
	 */
	public void finallyAfterUndelete() {
		return;
	}
}