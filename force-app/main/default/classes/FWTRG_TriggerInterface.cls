/**
 * @name: FWTRG_TriggerInterface
 * @version: 1.0
 * @creation date: 05/11/2025
 * @author: Jesus Piriz
 * @description Interface for Trigger Framework
 */
public interface FWTRG_TriggerInterface {
	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method bulk before insert
	 * @return: N/A
	 */
	void bulkBeforeInsert();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method bulk before update
	 * @return: N/A
	 */
	void bulkBeforeUpdate();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method bulk before delete
	 * @return: N/A
	 */
	void bulkBeforeDelete();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method bulk after insert
	 * @return: N/A
	 */
	void bulkAfterInsert();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method bulk after update
	 * @return: N/A
	 */
	void bulkAfterUpdate();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method bulk after delete
	 * @return: N/A
	 */
	void bulkAfterDelete();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method bulk after undelete
	 * @return: N/A
	 */
	void bulkAfterUndelete();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method before insert
	 * @param so SObject
	 * @return: N/A
	 */
	void beforeInsert(SObject so);

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method before update
	 * @param oldSo SObject
	 * @param so SObject
	 * @return: N/A
	 */
	void beforeUpdate(SObject oldSo, SObject so);

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method before delete
	 * @param so SObject
	 * @return: N/A
	 */
	void beforeDelete(SObject so);

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method after insert
	 * @param so SObject
	 * @return: N/A
	 */
	void afterInsert(SObject so);

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method after update
	 * @param oldSo SObject
	 * @param so SObject
	 * @return: N/A
	 */
	void afterUpdate(SObject oldSo, SObject so);

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method after delete
	 * @param so SObject
	 * @return: N/A
	 */
	void afterDelete(SObject so);

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method after undelete
	 * @param so SObject
	 * @return: N/A
	 */
	void afterUndelete(SObject so);

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method finally before insert
	 * @return: N/A
	 */
	void finallyBeforeInsert();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method finally before update
	 * @return: N/A
	 */
	void finallyBeforeUpdate();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method finally before delete
	 * @return: N/A
	 */
	void finallyBeforeDelete();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method finally after insert
	 * @return: N/A
	 */
	void finallyAfterInsert();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method finally after update
	 * @return: N/A
	 */
	void finallyAfterUpdate();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method finally after delete
	 * @return: N/A
	 */
	void finallyAfterDelete();

	/**
	 * @version: 1.0
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method finally after undelete
	 * @return: N/A
	 */
	void finallyAfterUndelete();
}