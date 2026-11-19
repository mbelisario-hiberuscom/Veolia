/**
 * @name FWTRG_TriggerFactoryTest
 * @version 1.0
 * @creation date: 05/11/2025
 * @author: Jesus Piriz
 * @description Test class for testing the functionality of FWTRG_TriggerFactory class
 **/
@IsTest
public with sharing class FWTRG_TriggerFactoryTest {
	/**
	 * @name: initialSetup
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Method to create the necessary data for this test.
	 */
	@TestSetup
	static voId initialSetup() {
		//Settings for FWBYP
		FWBYP_Settings__c recordSetting = new FWBYP_Settings__c();
		recordSetting.Name = 'Test';
		recordSetting.FWBYP_AllTriggers__c = true;
		recordSetting.SetupOwnerId = UserInfo.getProfileId();
		insert recordSetting;

		//Log Error for delete
		FWERR_ErrorLog__c testDelete = new FWERR_ErrorLog__c();
		testDelete.FWERR_MethodTxt__c = 'testDelete';
		insert testDelete;

		//Log Error for update
		FWERR_ErrorLog__c testUpdate = new FWERR_ErrorLog__c();
		testUpdate.FWERR_MethodTxt__c = 'testUpdate';
		insert testUpdate;

		//Log Error for undelete
		FWERR_ErrorLog__c testUndelete = new FWERR_ErrorLog__c();
		testUndelete.FWERR_MethodTxt__c = 'testUndelete';
		insert testUndelete;
	}

	/**
	 * @name: insertTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for insert operation
	 */
	@IsTest
	static voId insertTest() {
		FWERR_ErrorLog__c testError = new FWERR_ErrorLog__c();

		Test.startTest();
		insert testError;
		Test.stopTest();

		List<FWERR_ErrorLog__c> testList = [SELECT Id FROM FWERR_ErrorLog__c WHERE Id = :testError.Id LIMIT 1];
		System.assertEquals(true, testList.contains(testError));
	}

	/**
	 * @name: deleteTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for delete operation
	 */
	@IsTest
	static voId deleteTest() {
		FWERR_ErrorLog__c testDelete = [SELECT Id FROM FWERR_ErrorLog__c WHERE FWERR_MethodTxt__c = 'testDelete' LIMIT 1].get(0);

		Test.startTest();
		delete testDelete;
		Test.stopTest();

		List<FWERR_ErrorLog__c> testList = [SELECT Id FROM FWERR_ErrorLog__c WHERE Id = :testDelete.Id LIMIT 1];
		System.assertEquals(false, testList.contains(testDelete));
	}

	/**
	 * @name: undeleteTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for undelete operation
	 */
	@IsTest
	static voId undeleteTest() {
		FWERR_ErrorLog__c testUndelete = [SELECT Id FROM FWERR_ErrorLog__c WHERE FWERR_MethodTxt__c = 'testUndelete' LIMIT 1].get(0);
		delete testUndelete;

		Test.startTest();
		undelete testUndelete;
		Test.stopTest();

		List<FWERR_ErrorLog__c> testList = [SELECT Id FROM FWERR_ErrorLog__c WHERE FWERR_MethodTxt__c = 'testUndelete' LIMIT 1];
		System.assertEquals(true, testList.contains(testUndelete));
	}

	/**
	 * @name: updateTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for update operation
	 */
	@IsTest
	static voId updateTest() {
		FWERR_ErrorLog__c testError = [SELECT Id, FWERR_MethodTxt__c FROM FWERR_ErrorLog__c WHERE FWERR_MethodTxt__c = 'testUpdate' LIMIT 1];
		testError.FWERR_MethodTxt__c = 'testingFrameWorkTest';

		Test.startTest();
		update testError;
		Test.stopTest();

		System.assertEquals('testingFrameWorkTest', testError.FWERR_MethodTxt__c);
	}

	/**
	 * @name: runningMethodsDisableTriggerTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for disableTrigger method
	 */
	@IsTest
	static voId runningMethodsDisableTriggerTest() {
		String objName = 'FWERR_ErrorLog__c';
		Test.startTest();
		FWTRG_TriggerFactory.disableTrigger(objName);
		Test.stopTest();

		System.assertEquals(true, FWTRG_TriggerFactory.disabledTriggers.contains(objName.toLowerCase()));
	}

	/**
	 * @name: runningMethodsEnableTriggerTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for enableTrigger method
	 */
	@IsTest
	static voId runningMethodsEnableTriggerTest() {
		Test.startTest();
		FWTRG_TriggerFactory.enableTrigger('FWERR_ErrorLog__c');
		Test.stopTest();

		System.assertEquals(false, FWTRG_TriggerFactory.disabledTriggers.contains('FWERR_ErrorLog__c'));
	}

	/**
	 * @name: runningMethodsTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for isDisabled method
	 */
	@IsTest
	static voId runningMethodsTest() {
		Test.startTest();
		FWTRG_TriggerFactory.isDisabled('FWERR_ErrorLog__c');
		Test.stopTest();

		System.assertEquals(false, FWTRG_TriggerFactory.isDisabled('FWERR_ErrorLog__c'));
	}

	/**
	 * @name: isChangedTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for isFieldChanged method
	 */
	@IsTest
	static voId isChangedTest() {
		FWERR_ErrorLog__c testError = [SELECT Id, FWERR_MethodTxt__c FROM FWERR_ErrorLog__c WHERE FWERR_MethodTxt__c = 'testUpdate' LIMIT 1];

		Boolean isChanged;

		Test.startTest();
		isChanged = FWTRG_TriggerFactory.isFieldChanged(testError, testError, FWERR_ErrorLog__c.FWERR_MethodTxt__c);
		Test.stopTest();

		System.assertEquals(false, isChanged);
	}

	/**
	 * @name: checkAndExecuteWithDisabledTriggerTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for checkAndExecute method with disabled trigger
	 */
	@IsTest
	static voId checkAndExecuteWithDisabledTriggerTest() {
		// Arrange
		String testObject = 'TestObjectWithNameTooLong__c';
		FWTRG_TriggerFactory.disableTrigger(testObject);

		MockTriggerHandler mockHandler = new MockTriggerHandler();

		// Act
		Test.startTest();
		FWTRG_TriggerFactory.checkAndExecute(testObject, MockTriggerHandler.class);
		Test.stopTest();

		// Assert
		System.assert(!mockHandler.wasExecuted, 'The handler should not be executed for a disabled trigger.');
	}

	/**
	 * @name: executeTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for execute
	 */
	@IsTest
	static void executeTest() {
		MockTriggerHandler mockHandler = new MockTriggerHandler();

		Boolean hasTriggerException = false;
		try {
			Test.startTest();
			FWTRG_TriggerFactory.execute(mockHandler);
			Test.stopTest();
		} catch (Exception e) {
			hasTriggerException = true;
		}

		System.assertEquals(false, hasTriggerException);
	}

	/**
	 * @name: executeBeforeInsertTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for execute
	 */
	@IsTest
	static void executeBeforeInsertTest() {
		FWTRG_TriggerFactory.testingTriggerFramework = true;
		FWTRG_TriggerFactory.triggerIsBefore = true;
		FWTRG_TriggerFactory.triggerIsInsert = true;

		MockTriggerHandler mockHandler = new MockTriggerHandler();

		Boolean hasTriggerException = false;
		try {
			Test.startTest();
			FWTRG_TriggerFactory.execute(mockHandler);
			Test.stopTest();
		} catch (Exception e) {
			hasTriggerException = true;
		}

		System.assertEquals(false, hasTriggerException);
	}

	/**
	 * @name: executeBeforeUpdateTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for execute
	 */
	@IsTest
	static void executeBeforeUpdateTest() {
		FWTRG_TriggerFactory.testingTriggerFramework = true;
		FWTRG_TriggerFactory.triggerIsBefore = true;
		FWTRG_TriggerFactory.triggerIsUpdate = true;

		MockTriggerHandler mockHandler = new MockTriggerHandler();

		Boolean hasTriggerException = false;
		try {
			Test.startTest();
			FWTRG_TriggerFactory.execute(mockHandler);
			Test.stopTest();
		} catch (Exception e) {
			hasTriggerException = true;
		}

		System.assertEquals(false, hasTriggerException);
	}

	/**
	 * @name: executeBeforeDeleteTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for execute
	 */
	@IsTest
	static void executeBeforeDeleteTest() {
		FWTRG_TriggerFactory.testingTriggerFramework = true;
		FWTRG_TriggerFactory.triggerIsBefore = true;
		FWTRG_TriggerFactory.triggerIsDelete = true;

		MockTriggerHandler mockHandler = new MockTriggerHandler();

		Boolean hasTriggerException = false;
		try {
			Test.startTest();
			FWTRG_TriggerFactory.execute(mockHandler);
			Test.stopTest();
		} catch (Exception e) {
			hasTriggerException = true;
		}

		System.assertEquals(false, hasTriggerException);
	}

	/**
	 * @name: executeAfterInsertTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for execute
	 */
	@IsTest
	static void executeAfterInsertTest() {
		FWTRG_TriggerFactory.testingTriggerFramework = true;
		FWTRG_TriggerFactory.triggerIsAfter = true;
		FWTRG_TriggerFactory.triggerIsInsert = true;

		MockTriggerHandler mockHandler = new MockTriggerHandler();

		Boolean hasTriggerException = false;
		try {
			Test.startTest();
			FWTRG_TriggerFactory.execute(mockHandler);
			Test.stopTest();
		} catch (Exception e) {
			hasTriggerException = true;
		}

		System.assertEquals(false, hasTriggerException);
	}

	/**
	 * @name: executeAfterUpdateTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for execute
	 */
	@IsTest
	static void executeAfterUpdateTest() {
		FWTRG_TriggerFactory.testingTriggerFramework = true;
		FWTRG_TriggerFactory.triggerIsAfter = true;
		FWTRG_TriggerFactory.triggerIsUpdate = true;

		MockTriggerHandler mockHandler = new MockTriggerHandler();

		Boolean hasTriggerException = false;
		try {
			Test.startTest();
			FWTRG_TriggerFactory.execute(mockHandler);
			Test.stopTest();
		} catch (Exception e) {
			hasTriggerException = true;
		}

		System.assertEquals(false, hasTriggerException);
	}

	/**
	 * @name: executeAfterDeleteTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for execute
	 */
	@IsTest
	static void executeAfterDeleteTest() {
		FWTRG_TriggerFactory.testingTriggerFramework = true;
		FWTRG_TriggerFactory.triggerIsAfter = true;
		FWTRG_TriggerFactory.triggerIsDelete = true;

		MockTriggerHandler mockHandler = new MockTriggerHandler();

		Boolean hasTriggerException = false;
		try {
			Test.startTest();
			FWTRG_TriggerFactory.execute(mockHandler);
			Test.stopTest();
		} catch (Exception e) {
			hasTriggerException = true;
		}

		System.assertEquals(false, hasTriggerException);
	}

	/**
	 * @name: executeAfterUndeleteTest
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Test method for execute
	 */
	@IsTest
	static void executeAfterUndeleteTest() {
		FWTRG_TriggerFactory.testingTriggerFramework = true;
		FWTRG_TriggerFactory.triggerIsAfter = true;
		FWTRG_TriggerFactory.triggerIsUndelete = true;

		MockTriggerHandler mockHandler = new MockTriggerHandler();

		Boolean hasTriggerException = false;
		try {
			Test.startTest();
			FWTRG_TriggerFactory.execute(mockHandler);
			Test.stopTest();
		} catch (Exception e) {
			hasTriggerException = true;
		}

		System.assertEquals(false, hasTriggerException);
	}

	/**
	 * @name: MockTriggerHandler
	 * @creation date: 05/11/2025
	 * @author: Jesus Piriz
	 * @description Mock implementation of FWTRG_TriggerInterface
	 */
	private class MockTriggerHandler implements FWTRG_TriggerInterface {
		public Boolean wasExecuted = false;

		/**
		 * @description Implementation of method bulk before insert
		 */
		public void bulkBeforeInsert() {
			wasExecuted = true;
		}

		/**
		 * @description Implementation of method before insert
		 * @param obj SObject
		 */
		public void beforeInsert(SObject obj) {
			return;
		}

		/**
		 * @description Implementation of method finally before insert
		 */
		public void finallyBeforeInsert() {
			return;
		}

		/**
		 * @description Implementation of method bulk before update
		 */
		public void bulkBeforeUpdate() {
			return;
		}

		/**
		 * @description Implementation of method before update
		 * @param oldObj SObject
		 * @param newObj SObject
		 */
		public void beforeUpdate(SObject oldObj, SObject newObj) {
			return;
		}

		/**
		 * @description Implementation of method finally before update
		 */
		public void finallyBeforeUpdate() {
			return;
		}

		/**
		 * @description Implementation of method bulk before delete
		 */
		public void bulkBeforeDelete() {
			return;
		}

		/**
		 * @description Implementation of method before delete
		 * @param obj SObject
		 */
		public void beforeDelete(SObject obj) {
			return;
		}

		/**
		 * @description Implementation of method finally before delete
		 */
		public void finallyBeforeDelete() {
			return;
		}

		/**
		 * @description Implementation of method bulk after insert
		 */
		public void bulkAfterInsert() {
			wasExecuted = true;
		}

		/**
		 * @description Implementation of method after insert
		 * @param obj SObject
		 */
		public void afterInsert(SObject obj) {
			return;
		}

		/**
		 * @description Implementation of method finally after insert
		 */
		public void finallyAfterInsert() {
			return;
		}

		/**
		 * @description Implementation of method bulk after update
		 */
		public void bulkAfterUpdate() {
			return;
		}

		/**
		 * @description Implementation of method bulk after update
		 * @param oldObj SObject
		 * @param newObj SObject
		 */
		public void afterUpdate(SObject oldObj, SObject newObj) {
			return;
		}

		/**
		 * @description Implementation of method finally after update
		 */
		public void finallyAfterUpdate() {
			return;
		}

		/**
		 * @description Implementation of method bulk after delete
		 */
		public void bulkAfterDelete() {
			return;
		}

		/**
		 * @description Implementation of method after delete
		 * @param obj SObject
		 */
		public void afterDelete(SObject obj) {
			return;
		}

		/**
		 * @description Implementation of method finally after delete
		 */
		public void finallyAfterDelete() {
			return;
		}

		/**
		 * @description Implementation of method bulk after undelete
		 */
		public void bulkAfterUndelete() {
			return;
		}

		/**
		 * @description Implementation of method after undelete
		 * @param obj SObject
		 */
		public void afterUndelete(SObject obj) {
			return;
		}

		/**
		 * @description Implementation of method finally after undelete
		 */
		public void finallyAfterUndelete() {
			return;
		}
	}
}