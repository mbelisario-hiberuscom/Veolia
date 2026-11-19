/**
 * @name VL_ContentDocumentLinkTrigger
 * @version 1.0
 * @creation date: 01/09/2026
 * @author: Jesus Piriz
 * @description Trigger for ContentDocumentLink object
 **/
trigger VL_ContentDocumentLinkTrigger on ContentDocumentLink(after insert) {
	FWTRG_TriggerFactory.checkAndExecute(
		ContentDocumentLink.sObjectType.getDescribe().getName(),
		VL_ContentDocumentLinkTriggerHandler.class
	);
}