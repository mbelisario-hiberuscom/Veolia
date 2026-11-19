import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

import getCustomerHeader from '@salesforce/apex/VL_CustomerHeaderController.getCustomerHeader';

export default class CustomerHeader extends NavigationMixin(LightningElement) {
	@api recordId;
	@api editRecordFlowApiName;
	objectInfoData;
	isEditRecordFlowOpen = false;
	activeEditRecordFlowName;
	data;
	wiredCustomerHeaderResult;

	@wire(getCustomerHeader, { accountId: '$recordId' })
	wiredData(result) {
		this.wiredCustomerHeaderResult = result;
		const { data, error } = result;
		if (data) {
			this.objectInfoData = data;
			this.data = data;
		} else if (error) {
			this.data = undefined;
		}
	}

	get accountName() {
		return this.data?.accountName || '-';
	}

	get isActive() {
		return this.data?.isActive ? 'Activo' : 'Inactivo';
	}

	get isActiveClass() {
		return this.data?.isActive ? 'header-badge badge active' : 'header-badge badge inactive';
	}

	get starRating() {
		return this.data?.starRating;
	}

	get npsStars() {
		const value = Number(this.data?.starRating || 0);
		return [1, 2, 3, 4, 5].map((item) => {
			return {
				key: item,
				className: item <= value ? 'star-filled' : 'star-empty'
			};
		});
	}

	get customerPriority() {
		console.log('Customer Priority:', this.data?.customerPriority);
		return this.data?.customerPriority;
	}

	get customerPriorityClass() {
		const priority = this.data?.customerPriority;
		switch (priority) {
			case 'Tier 1':
				return 'header-badge priority-tier-1';
			case 'Tier 2':
				return 'header-badge priority-tier-2';
			case 'Tier 3':
				return 'header-badge priority-tier-3';
			case 'Tier 4':
				return 'header-badge priority-tier-4';
			default:
				return 'header-badge priority-other';
		}
	}

	get financialScoring() {
		return this.data?.financialScoring;
	}

	get objectLabel() {
		return this.objectInfoData?.label || this.objectApiName || 'registro';
	}

	get editRecordLabel() {
		// return `Editar ${this.objectLabel}`;
		return 'Editar Cuenta';
	}

	get financialRiskLabel() {
		const value = Number(this.financialScoring);
		if (this.financialScoring === null || this.financialScoring === undefined || Number.isNaN(value)) {
			return 'No disponible';
		}
		if (value <= 3) {
			return `Bajo (${value}/10)`;
		}
		if (value <= 6) {
			return `Medio (${value}/10)`;
		}
		if (value <= 8) {
			return `Alto (${value}/10)`;
		}
		return `Crítico (${value}/10)`;
	}

	get financialRiskBadgeClass() {
		const value = Number(this.financialScoring);
		if (this.financialScoring === null || this.financialScoring === undefined || Number.isNaN(value)) {
			return 'header-badge risk-gray';
		}
		if (value <= 3) {
			return 'header-badge risk-green';
		}
		if (value <= 6) {
			return 'header-badge risk-yellow';
		}
		if (value <= 8) {
			return 'header-badge risk-orange';
		}
		return 'header-badge risk-red';
	}

	get ownerName() {
		return this.data?.ownerName || '-';
	}

	get documentNumber() {
		return this.data?.documentNumber;
	}

	get businessGroup() {
		return this.data?.businessGroup;
	}

	get type() {
		return this.data?.type;
	}

	get marketSegment() {
		return this.data?.marketSegment;
	}

	get phone() {
		return this.data?.phone;
	}

	get items() {
		return [
			{
				label: 'Pipeline abierto',
				value: this.data?.pipelineAmountFormatted || '€ 0',
				icon: 'utility:target',
				iconClass: 'kpi-icon kpi-orange'
			},
			{
				label: 'Oportunidades abiertas',
				value: this.data?.openOpportunities || 0,
				icon: 'utility:opportunity',
				iconClass: 'kpi-icon kpi-green'
			},
			{
				label: 'Oportunidades ganadas',
				value: this.data?.wonOpportunities || 0,
				icon: 'utility:success',
				iconClass: 'kpi-icon kpi-yellow'
			},
			{
				label: 'Casos abiertos',
				value: this.data?.openCases || 0,
				icon: 'utility:case',
				iconClass: 'kpi-icon kpi-purple'
			},
			{
				label: 'Contratos activos',
				value: this.data?.activeContracts || 0,
				icon: 'utility:contract',
				iconClass: 'kpi-icon kpi-blue'
			}
		];
	}

	handleEdit() {
		const flowApiName = String(this.editRecordFlowApiName || '').trim();
		if (flowApiName) {
			this.activeEditRecordFlowName = flowApiName;
			this.editRecordFlowInputVariables = [{ name: 'recordId', type: 'String', value: this.recordId }];
			this.isEditRecordFlowOpen = true;
			return;
		}
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: this.recordId,
				objectApiName: 'Account',
				actionName: 'edit'
			}
		});
	}

	closeEditRecordFlow() {
		this.isEditRecordFlowOpen = false;
		this.activeEditRecordFlowName = undefined;
		this.editRecordFlowInputVariables = undefined;
	}

	async handleEditRecordFlowStatusChange(event) {
		if (['FINISHED', 'FINISHED_SCREEN'].includes(event.detail.status)) {
			if (this.wiredCustomerHeaderResult) {
				await refreshApex(this.wiredCustomerHeaderResult);
			}
			this.closeEditRecordFlow();
		}
	}

	handleNewCase() {
		this.navigateNewRecord('Case');
	}

	handleNewOpportunity() {
		this.navigateNewRecord('Opportunity');
	}

	navigateNewRecord(objectApiName) {
		this[NavigationMixin.Navigate]({
			type: 'standard__objectPage',
			attributes: {
				objectApiName,
				actionName: 'new'
			},
			state: {
				defaultFieldValues: `AccountId=${this.recordId}`
			}
		});
	}
}