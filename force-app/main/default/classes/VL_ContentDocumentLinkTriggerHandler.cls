/**
 * @name VL_ContentDocumentLinkTriggerHandler
 * @version 1.0
 * @creation date: 27/08/2026
 * @author: Jesus Piriz
 * @description FWTRG trigger handler for ContentDocumentLink.
 *              Accumulates after-insert records and delegates to the helper in finallyAfterInsert.
 */
public with sharing class VL_ContentDocumentLinkTriggerHandler implements FWTRG_TriggerInterface {
	private List<ContentDocumentLink> pendingLinks = new List<ContentDocumentLink>();

	/**
	 * @description Implementation of method bulk before insert
	 */
	public void bulkBeforeInsert() {
	}
	/**
	 * @description Implementation of method bulk before update
	 */
	public void bulkBeforeUpdate() {
	}
	/**
	 * @description Implementation of method bulk before delete
	 */
	public void bulkBeforeDelete() {
	}
	/**
	 * @description Implementation of method bulk after insert
	 */
	public void bulkAfterInsert() {
		pendingLinks = new List<ContentDocumentLink>();
	}
	/**
	 * @description Implementation of method bulk after update
	 */
	public void bulkAfterUpdate() {
	}
	/**
	 * @description Implementation of method bulk after delete
	 */
	public void bulkAfterDelete() {
	}
	/**
	 * @description Implementation of method bulk after undelete
	 */
	public void bulkAfterUndelete() {
	}
	/**
	 * @description Implementation of method before insert
	 * @param so Record being inserted
	 */
	public void beforeInsert(SObject so) {
	}
	/**
	 * @description Implementation of method before update
	 * @param oldSo Previous version of the record
	 * @param so Current version of the record
	 */
	public void beforeUpdate(SObject oldSo, SObject so) {
	}
	/**
	 * @description Implementation of method before delete
	 * @param so Record being deleted
	 */
	public void beforeDelete(SObject so) {
	}
	/**
	 * @description Implementation of method after insert
	 * @param so Record being inserted
	 */
	public void afterInsert(SObject so) {
		pendingLinks.add((ContentDocumentLink) so);
	}
	/**
	 * @description Implementation of method after update
	 * @param oldSo Previous version of the record
	 * @param so Current version of the record
	 */
	public void afterUpdate(SObject oldSo, SObject so) {
	}
	/**
	 * @description Implementation of method after delete
	 * @param so Record being deleted
	 */
	public void afterDelete(SObject so) {
	}
	/**
	 * @description Implementation of method after undelete
	 * @param so Record being undeleted
	 */
	public void afterUndelete(SObject so) {
	}
	/**
	 * @description Implementation of method finally before insert
	 */
	public void finallyBeforeInsert() {
	}
	/**
	 * @description Implementation of method finally before update
	 */
	public void finallyBeforeUpdate() {
	}
	/**
	 * @description Implementation of method finally before delete
	 */
	public void finallyBeforeDelete() {
	}
	/**
	 * @description Implementation of method finally after insert
	 */
	public void finallyAfterInsert() {
		VL_ContentDocumentLinkTriggerHelper.handleAfterInsert(pendingLinks);
	}
	/**
	 * @description Implementation of method finally after update
	 */
	public void finallyAfterUpdate() {
	}
	/**
	 * @description Implementation of method finally after delete
	 */
	public void finallyAfterDelete() {
	}
	/**
	 * @description Implementation of method finally after undelete
	 */
	public void finallyAfterUndelete() {
	}
}