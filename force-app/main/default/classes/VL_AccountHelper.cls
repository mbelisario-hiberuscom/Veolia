/**
 * @name: VL_AccountHelper
 * @version: 1.0
 * @creation date: 01/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Bulk-safe Account validations and synchronization with related Locations.
 */
@SuppressWarnings('PMD.ApexDoc')
public inherited sharing class VL_AccountHelper {
	private static final String FISCAL_FORMAT_ERROR = 'El CIF/NIF/NIE es obligatorio y debe tener un formato válido.';

	public static void validateFiscalNumbersFormat(List<Account> accounts) {
		if (accounts == null || accounts.isEmpty()) {
			return;
		}
		List<VL_FiscalNumberValidator.Request> requests = new List<VL_FiscalNumberValidator.Request>();
		for (Account account : accounts) {
			VL_FiscalNumberValidator.Request request = new VL_FiscalNumberValidator.Request();
			request.fiscalNumber = account.VL_FiscalNumber__c;
			requests.add(request);
		}
		List<VL_FiscalNumberValidator.Response> responses = VL_FiscalNumberValidator.validateFiscalNumbers(requests);
		for (Integer accountIndex = 0; accountIndex < accounts.size(); accountIndex++) {
			if (!responses[accountIndex].isValid) {
				accounts[accountIndex].addError(FISCAL_FORMAT_ERROR);
			}
		}
	}

	public static void validateFiscalNumbers(List<Account> accounts, Map<Id, Account> oldAccountsById) {
		VL_AccountFiscalHelper.validateDuplicates(accounts, oldAccountsById);
		VL_AccountNameDuplicateHelper.validateDuplicates(accounts, oldAccountsById);
	}
}