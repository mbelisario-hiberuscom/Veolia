public with sharing class VL_CustomerHeaderController {
	@AuraEnabled(cacheable=true)
	public static CustomerHeaderDTO getCustomerHeader(Id accountId) {
		if (accountId == null) {
			return null;
		}

		List<Account> accounts = [
			SELECT
				Id,
				Name,
				VL_Active__c,
				VL_StarRating__c,
				VL_CustomerPriority__c,
				VL_KAM__r.Name,
				VL_FiscalNumber__c,
				VL_BusinessGroup__r.Name,
				Type,
				VL_MarketSegment__c,
				Phone,
				VL_FinancialScoring__c
			FROM Account
			WHERE Id = :accountId
			LIMIT 1
		];

		if (accounts.isEmpty()) {
			return null;
		}

		Account account = accounts[0];

		AggregateResult oppAgg = [
			SELECT COUNT(Id) totalOpps, SUM(Amount) totalAmount
			FROM Opportunity
			WHERE AccountId = :accountId AND IsClosed = FALSE
		];

		AggregateResult wonOpportunities = [
			SELECT COUNT(Id) wons
			FROM Opportunity
			WHERE AccountId = :accountId AND IsWon = TRUE
		];

		Integer openCases = [
			SELECT COUNT()
			FROM Case
			WHERE AccountId = :accountId AND IsClosed = FALSE
		];

		Integer activeContracts = [
			SELECT COUNT()
			FROM Contract
			WHERE AccountId = :accountId AND Status = 'Active'
		];

		Decimal pipeline = (Decimal) oppAgg.get('totalAmount');

		CustomerHeaderDTO dto = new CustomerHeaderDTO();
		dto.accountName = account.Name;
		dto.isActive = account.VL_Active__c; // == true
		dto.starRating = null;
		if (account.VL_StarRating__c != null) {
			dto.starRating = Decimal.valueOf(String.valueOf(account.VL_StarRating__c));
		}
		dto.customerPriority = account.VL_CustomerPriority__c;
		dto.ownerName = account.VL_KAM__r == null ? null : account.VL_KAM__r.Name;
		dto.documentNumber = account.VL_FiscalNumber__c;
		dto.businessGroup = account.VL_BusinessGroup__r == null ? null : account.VL_BusinessGroup__r.Name;
		dto.type = account.Type;
		dto.marketSegment = account.VL_MarketSegment__c;
		dto.phone = account.Phone;
		dto.pipelineAmount = pipeline == null ? 0 : pipeline;
		dto.pipelineAmountFormatted = '€ ' + dto.pipelineAmount.setScale(0).format();
		dto.openOpportunities = (Integer) oppAgg.get('totalOpps');
		dto.wonOpportunities = (Integer) wonOpportunities.get('wons');
		dto.financialScoring = account.VL_FinancialScoring__c;
		dto.openCases = openCases;
		dto.activeContracts = activeContracts;
		return dto;
	}

	public class CustomerHeaderDTO {
		@AuraEnabled
		public String accountName { get; set; }
		@AuraEnabled
		public Boolean isActive { get; set; }
		@AuraEnabled
		public Decimal starRating { get; set; }
		@AuraEnabled
		public String ownerName { get; set; }
		@AuraEnabled
		public String documentNumber { get; set; }
		@AuraEnabled
		public String businessGroup { get; set; }
		@AuraEnabled
		public String type { get; set; }
		@AuraEnabled
		public String marketSegment { get; set; }
		@AuraEnabled
		public String phone { get; set; }
		@AuraEnabled
		public String customerPriority { get; set; }
		@AuraEnabled
		public Decimal pipelineAmount { get; set; }
		@AuraEnabled
		public String pipelineAmountFormatted { get; set; }
		@AuraEnabled
		public Integer openOpportunities { get; set; }
		@AuraEnabled
		public Integer wonOpportunities { get; set; }
		@AuraEnabled
		public Decimal financialScoring { get; set; }
		@AuraEnabled
		public Integer openCases { get; set; }
		@AuraEnabled
		public Integer activeContracts { get; set; }
	}
}