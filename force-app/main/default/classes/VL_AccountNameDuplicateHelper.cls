/**
 * @name: VL_AccountNameDuplicateHelper
 * @version: 1.0
 * @creation date: 01/09/2026
 * @author: Alejandro Bueno Gimenez
 * @description Bulk-safe validation of logical Account name duplicates.
 */
@SuppressWarnings('PMD.ApexDoc')
public inherited sharing class VL_AccountNameDuplicateHelper {
	private static final String NAME_DUPLICATE_ERROR = 'El nombre de Account ya existe en la cuenta {0}. Contacte con un administrador si necesita crear un duplicado.';
	private static final String BYPASS_REASON_ERROR = 'Debe informar el motivo para permitir un nombre duplicado.';
	private static final String BYPASS_PERMISSION = 'VL_Bypass_Rules';
	private static final String AUDIT_RULE = 'Account name duplicate';

	/**
	 * @name: DuplicateValidationContext
	 * @version: 1.0
	 * @creation date: 01/09/2026
	 * @author: Alejandro Bueno Gimenez
	 * @description Shared state for name duplicate handling and audit collection.
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
		Map<String, List<Account>> accountsByName = collectIncomingAccounts(accounts, oldAccountsById);
		if (accountsByName.isEmpty()) {
			return;
		}
		DuplicateValidationContext context = new DuplicateValidationContext(
			FeatureManagement.checkPermission(BYPASS_PERMISSION),
			Schema.sObjectType.VL_Audit_Log__c.isCreateable()
		);
		markExistingDuplicates(accountsByName, context);
		markBatchDuplicates(accountsByName, context);
		if (context.auditLogs != null && !context.auditLogs.isEmpty()) {
			insert context.auditLogs;
		}
	}

	private static Map<String, List<Account>> collectIncomingAccounts(List<Account> accounts, Map<Id, Account> oldAccountsById) {
		Map<String, List<Account>> accountsByName = new Map<String, List<Account>>();
		for (Account account : accounts) {
			if (isNameUnchanged(account, oldAccountsById)) {
				continue;
			}
			String normalizedName = normalizeName(account.Name);
			if (String.isBlank(normalizedName)) {
				continue;
			}
			if (!accountsByName.containsKey(normalizedName)) {
				accountsByName.put(normalizedName, new List<Account>());
			}
			accountsByName.get(normalizedName).add(account);
		}
		return accountsByName;
	}

	private static Boolean isNameUnchanged(Account account, Map<Id, Account> oldAccountsById) {
		if (oldAccountsById == null || !oldAccountsById.containsKey(account.Id)) {
			return false;
		}
		return normalizeName(account.Name) == normalizeName(oldAccountsById.get(account.Id).Name);
	}

	private static void markExistingDuplicates(Map<String, List<Account>> accountsByName, DuplicateValidationContext context) {
		Set<String> names = accountsByName.keySet();
		for (Account existingAccount : [SELECT Id, Name FROM Account WHERE Name IN :names WITH USER_MODE]) {
			List<Account> incomingAccounts = accountsByName.get(normalizeName(existingAccount.Name));
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

	private static void markBatchDuplicates(Map<String, List<Account>> accountsByName, DuplicateValidationContext context) {
		for (List<Account> incomingAccounts : accountsByName.values()) {
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
			incomingAccount.addError(String.format(NAME_DUPLICATE_ERROR, new List<String>{ duplicateAccountName }));
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
				VL_BypassReason__c = incomingAccount.VL_BypassReason__c,
				VL_Rule__c = AUDIT_RULE
			)
		);
	}

	private static String normalizeName(String accountName) {
		return String.isBlank(accountName) ? null : accountName.trim().toUpperCase();
	}
}