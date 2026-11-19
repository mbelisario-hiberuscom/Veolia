/**
 * @name: VL_AccountFiscalHelper
 * @version: 1.0
 * @creation date: 01/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Bulk-safe duplicate validation for Account fiscal numbers.
 */
@SuppressWarnings('PMD.ApexDoc')
public inherited sharing class VL_AccountFiscalHelper {
	private static final String FISCAL_DUPLICATE_ERROR = 'El CIF ya existe en la cuenta {0}. Contacte con un administrador si necesita crear un duplicado.';
	private static final String BYPASS_REASON_ERROR = 'Debe informar el motivo para permitir un CIF duplicado.';
	private static final String BYPASS_PERMISSION = 'VL_Bypass_Rules';
	private static final String AUDIT_RULE = 'Account fiscal number duplicate';

	/**
	 * @name: DuplicateValidationContext
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Shared state for duplicate handling and audit collection.
	 */
	@SuppressWarnings('PMD.ApexDoc')
	private class DuplicateValidationContext {
		private Boolean canBypass;
		private Boolean canCreateAudit;
		private List<VL_Audit_Log__c> auditLogs;

		private DuplicateValidationContext(Boolean canBypass, Boolean canCreateAudit) {
			this.canBypass = canBypass;
			this.canCreateAudit = canCreateAudit;
			this.auditLogs = canCreateAudit ? new List<VL_Audit_Log__c>() : null;
		}
	}

	public static void validateDuplicates(List<Account> accounts, Map<Id, Account> oldAccountsById) {
		if (accounts == null || accounts.isEmpty() || !Schema.sObjectType.Account.isAccessible()) {
			return;
		}
		Map<String, List<Account>> accountsByFiscalNumber = new Map<String, List<Account>>();
		collectIncomingAccounts(accounts, oldAccountsById, accountsByFiscalNumber);
		if (accountsByFiscalNumber.isEmpty()) {
			return;
		}
		DuplicateValidationContext context = new DuplicateValidationContext(
			FeatureManagement.checkPermission(BYPASS_PERMISSION),
			Schema.sObjectType.VL_Audit_Log__c.isCreateable()
		);
		markExistingDuplicates(accountsByFiscalNumber, context);
		markBatchDuplicates(accountsByFiscalNumber, context);
		if (context.auditLogs != null && !context.auditLogs.isEmpty()) {
			insert context.auditLogs;
		}
	}

	private static void collectIncomingAccounts(
		List<Account> accounts,
		Map<Id, Account> oldAccountsById,
		Map<String, List<Account>> accountsByFiscalNumber
	) {
		for (Account account : accounts) {
			if (isFiscalNumberUnchanged(account, oldAccountsById)) {
				continue;
			}
			String fiscalNumber = normalizeFiscalNumber(account.VL_FiscalNumber__c);
			if (String.isBlank(fiscalNumber)) {
				continue;
			}
			account.VL_FiscalNumber__c = fiscalNumber;
			if (!accountsByFiscalNumber.containsKey(fiscalNumber)) {
				accountsByFiscalNumber.put(fiscalNumber, new List<Account>());
			}
			accountsByFiscalNumber.get(fiscalNumber).add(account);
		}
	}

	private static Boolean isFiscalNumberUnchanged(Account account, Map<Id, Account> oldAccountsById) {
		if (oldAccountsById == null || !oldAccountsById.containsKey(account.Id)) {
			return false;
		}
		return account.VL_FiscalNumber__c == oldAccountsById.get(account.Id).VL_FiscalNumber__c;
	}

	private static void markExistingDuplicates(Map<String, List<Account>> accountsByFiscalNumber, DuplicateValidationContext context) {
		for (Account existingAccount : [
			SELECT Id, Name, VL_FiscalNumber__c
			FROM Account
			WHERE VL_FiscalNumber__c IN :accountsByFiscalNumber.keySet()
		]) {
			List<Account> incomingAccounts = accountsByFiscalNumber.get(normalizeFiscalNumber(existingAccount.VL_FiscalNumber__c));
			if (incomingAccounts == null) {
				continue;
			}
			for (Account incomingAccount : incomingAccounts) {
				if (incomingAccount.Id == null || incomingAccount.Id != existingAccount.Id) {
					handleDuplicate(incomingAccount, existingAccount.Name, context);
				}
			}
		}
	}

	private static void markBatchDuplicates(Map<String, List<Account>> accountsByFiscalNumber, DuplicateValidationContext context) {
		for (List<Account> incomingAccounts : accountsByFiscalNumber.values()) {
			if (incomingAccounts.size() < 2) {
				continue;
			}
			for (Account incomingAccount : incomingAccounts) {
				handleDuplicate(incomingAccount, 'otra cuenta del mismo lote', context);
			}
		}
	}

	private static void handleDuplicate(Account incomingAccount, String duplicateAccountName, DuplicateValidationContext context) {
		if (!context.canBypass) {
			incomingAccount.addError(String.format(FISCAL_DUPLICATE_ERROR, new List<String>{ duplicateAccountName }));
			return;
		}
		if (String.isBlank(incomingAccount.VL_BypassReason__c)) {
			incomingAccount.addError(BYPASS_REASON_ERROR);
			return;
		}
		if (!context.canCreateAudit) {
			incomingAccount.addError('No tiene permisos para registrar la auditoría del bypass.');
			return;
		}
		context.auditLogs.add(
			new VL_Audit_Log__c(
				VL_Account__c = incomingAccount.Id,
				VL_FiscalNumber__c = normalizeFiscalNumber(incomingAccount.VL_FiscalNumber__c),
				VL_BypassReason__c = incomingAccount.VL_BypassReason__c,
				VL_Rule__c = AUDIT_RULE
			)
		);
	}

	private static String normalizeFiscalNumber(String fiscalNumber) {
		return String.isBlank(fiscalNumber) ? null : fiscalNumber.replaceAll('[\\s-]', '').toUpperCase();
	}
}