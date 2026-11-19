import { LightningElement, api } from 'lwc';
import findDuplicates from '@salesforce/apex/VL_AccountDuplicateController.findDuplicates';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
	{ label: 'Account', fieldName: 'accountName' },
	{ label: 'CIF', fieldName: 'fiscalNumber' },
	{ label: 'Coincidencia', fieldName: 'matchType' }
];

export default class Vl_AccountDuplicateResolver extends LightningElement {
	@api recordId;
	@api initialName;
	@api initialFiscalNumber;

	columns = COLUMNS;
	accountName = '';
	fiscalNumber = '';
	matches = [];
	isLoading = false;
	hasSearched = false;

	connectedCallback() {
		this.accountName = this.initialName || '';
		this.fiscalNumber = this.initialFiscalNumber || '';
	}

	get hasMatches() {
		return this.matches.length > 0;
	}

	get showEmptyState() {
		return this.hasSearched && !this.hasMatches && !this.isLoading;
	}

	handleNameChange(event) {
		this.accountName = event.target.value;
	}

	handleFiscalNumberChange(event) {
		this.fiscalNumber = event.target.value;
	}

	async handleSearch() {
		if (!this.accountName.trim() && !this.fiscalNumber.trim()) {
			this.showToast('Criterio requerido', 'Informe un nombre o un CIF.', 'warning');
			return;
		}
		this.isLoading = true;
		this.hasSearched = true;
		try {
			this.matches = await findDuplicates({
				accountId: this.recordId,
				fiscalNumber: this.fiscalNumber,
				accountName: this.accountName
			});
		} catch (error) {
			this.matches = [];
			this.showToast('Error', this.getErrorMessage(error), 'error');
		} finally {
			this.isLoading = false;
		}
	}

	showToast(title, message, variant) {
		this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
	}

	getErrorMessage(error) {
		return error?.body?.message || 'No se pudieron consultar las Accounts duplicadas.';
	}
}