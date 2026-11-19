import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getRecentlyViewedRecords from '@salesforce/apex/VL_RecentlyViewedRecordsController.getRecentlyViewedRecords';

import PREVIOUS_LABEL from '@salesforce/label/c.VL_Previous';
import NEXT_LABEL from '@salesforce/label/c.VL_Next';

const MIN_CARD_WIDTH = 320;
const CARD_GAP = 8;

export default class VlRecentlyViewedRecords extends NavigationMixin(LightningElement) {
	@api objectApiName;
	@api recordLimit = 5;
	@api fieldApiNames;
	@api cardActions;

	records = [];
	recordLoadingById = {};
	currentPage = 0;
	cardsPerView = 1;
	isLoading = true;
	errorMessage;
	objectIconName = '';
	resizeObserver;
	activeFlowName;
	activeFlowInputVariables = [];
	isFlowOpen = false;

	previousLabel = PREVIOUS_LABEL;
	nextLabel = NEXT_LABEL;

	renderedCallback() {
		const cardsContainer = this.template.querySelector('.cards');
		cardsContainer?.style.setProperty('--cards-per-view', this.cardsPerView);
		if (!this.resizeObserver) {
			if (cardsContainer && typeof ResizeObserver !== 'undefined') {
				this.resizeObserver = new ResizeObserver(([entry]) => this.updateCardsPerView(entry.contentRect.width));
				this.resizeObserver.observe(cardsContainer);
			}
		}
	}

	disconnectedCallback() {
		this.resizeObserver?.disconnect();
	}

	@wire(getObjectInfo, { objectApiName: '$objectApiName' })
	wiredObjectInfo({ data }) {
		if (data?.themeInfo?.iconUrl) {
			const iconParts = data.themeInfo.iconUrl.split('/');
			const iconFileName = iconParts[iconParts.length - 1];
			const iconName = iconFileName.substring(0, iconFileName.lastIndexOf('_'));
			this.objectIconName = `${iconParts[iconParts.length - 2]}:${iconName}`;
		}
	}

	@wire(getRecentlyViewedRecords, { objectApiName: '$objectApiName', recordLimit: '$recordLimit' })
	wiredRecentlyViewedRecords({ data, error }) {
		this.isLoading = false;
		if (data) {
			this.records = data;
			this.recordLoadingById = Object.fromEntries(data.map((record) => [record.recordId, true]));
			this.currentPage = 0;
			this.errorMessage = undefined;
		} else if (error) {
			this.records = [];
			this.recordLoadingById = {};
			this.errorMessage = this.getErrorMessage(error);
			this.showToast('Error', this.errorMessage, 'error');
		}
	}

	get configuredFields() {
		return (this.fieldApiNames || '')
			.split(',')
			.map((fieldApiName) => fieldApiName.trim())
			.filter((fieldApiName) => fieldApiName && fieldApiName !== 'Name');
	}

	get configuredActions() {
		if (Array.isArray(this.cardActions)) return this.cardActions;
		if (typeof this.cardActions !== 'string' || !this.cardActions.trim()) return [];
		try {
			const parsedActions = JSON.parse(this.cardActions);
			return Array.isArray(parsedActions) ? parsedActions : [];
		} catch {
			return [];
		}
	}

	get visibleRecords() {
		const visibleCount = Math.min(this.cardsPerView, this.records.length);
		return Array.from({ length: visibleCount }, (_, index) => {
			const recordIndex = (this.currentPage + index) % this.records.length;
			const record = this.records[recordIndex];
			return {
				...record,
				isRecordLoading: this.recordLoadingById[record.recordId] !== false,
				icon: this.objectIconName,
				actions: this.getRecordActions(record),
				fields: this.configuredFields.map((fieldApiName) => ({
					apiName: fieldApiName,
					key: `${record.recordId}-${fieldApiName}`
				}))
			};
		});
	}

	getRecordActions(record) {
		return this.configuredActions
			.filter((action) => action?.name && action?.label)
			.map((action) => ({
				...action,
				iconName: action.iconName || 'utility:forward',
				resolvedPageReference: action.type === 'navigate' ? this.resolvePageReference(action.pageReference, record) : undefined,
				resolvedFlowInputVariables:
					action.type === 'screenFlow' ? this.resolveFlowInputVariables(action.flowInputVariables, record) : undefined
			}));
	}

	resolveFlowInputVariables(inputVariables, record) {
		if (!Array.isArray(inputVariables)) return [];
		return inputVariables.map((inputVariable) => ({
			...inputVariable,
			value: this.resolvePageReference(inputVariable.value, record)
		}));
	}

	handleRecordLoad(event) {
		const recordId = event.currentTarget.dataset.recordId;
		this.recordLoadingById = { ...this.recordLoadingById, [recordId]: false };
	}

	get hasRecords() {
		return this.records.length > 0;
	}

	get carouselClass() {
		if (this.isLoading) return 'carousel loading-state';
		return this.hasRecords ? 'carousel records-state' : 'carousel empty-state';
	}

	get hasPagination() {
		return this.records.length > this.cardsPerView;
	}

	get carouselContentClass() {
		return this.hasPagination ? 'carousel-content has-navigation' : 'carousel-content';
	}

	get hasPreviousPage() {
		return this.hasPagination;
	}

	get hasNextPage() {
		return this.hasPagination;
	}

	get previousDisabled() {
		return !this.hasPreviousPage;
	}

	get nextDisabled() {
		return !this.hasNextPage;
	}

	updateCardsPerView(containerWidth) {
		const cardsThatFit = Math.max(1, Math.floor((containerWidth + CARD_GAP) / (MIN_CARD_WIDTH + CARD_GAP)));
		if (cardsThatFit !== this.cardsPerView) {
			this.cardsPerView = cardsThatFit;
			this.currentPage = this.records.length > 0 ? this.currentPage % this.records.length : 0;
			this.template.querySelector('.cards')?.style.setProperty('--cards-per-view', this.cardsPerView);
		}
	}

	navigateToRecord(event) {
		event.preventDefault();
		event.stopPropagation();
		const { recordId, objectApiName } = event.currentTarget.dataset;
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId,
				objectApiName,
				actionName: 'view'
			}
		});
	}

	handleCardAction(event) {
		event.stopPropagation();
		const actionName = event.currentTarget.dataset.actionName;
		const recordId = event.currentTarget.dataset.recordId;
		const record = this.records.find((item) => item.recordId === recordId);
		const action = this.getRecordActions(record).find((item) => item.name === actionName);
		if (!action || !record) return;
		if (action.type === 'navigate') {
			this.navigateAction(action, record);
			return;
		}
		if (action.type === 'screenFlow') {
			this.activeFlowName = action.flowName;
			const configuredInputVariables = action.resolvedFlowInputVariables || [];
			this.activeFlowInputVariables = [
				...configuredInputVariables.filter((inputVariable) => inputVariable.name !== 'recordId'),
				{ name: 'recordId', type: 'String', value: record.recordId }
			];
			this.isFlowOpen = true;
			return;
		}
		this.dispatchEvent(new CustomEvent('cardaction', { detail: { action, record } }));
	}

	closeFlow() {
		this.isFlowOpen = false;
		this.activeFlowName = undefined;
		this.activeFlowInputVariables = [];
	}

	handleFlowStatusChange(event) {
		if (event.detail.status === 'ERROR') {
			this.showToast('Error', 'No se pudo iniciar el flujo', 'error');
			return;
		}
		if (['FINISHED', 'FINISHED_SCREEN'].includes(event.detail.status)) this.closeFlow();
	}

	navigateAction(action, record) {
		const pageReference = action.resolvedPageReference || {
			type: 'standard__recordPage',
			attributes: { recordId: record.recordId, objectApiName: record.objectApiName, actionName: 'view' }
		};
		this[NavigationMixin.Navigate](pageReference);
	}

	resolvePageReference(value, record) {
		if (Array.isArray(value)) return value.map((item) => this.resolvePageReference(item, record));
		if (value && typeof value === 'object') {
			const resolvedValue = Object.fromEntries(
				Object.entries(value).map(([key, item]) => [key, this.resolvePageReference(item, record)])
			);
			if (resolvedValue.type === 'standard__recordPage') {
				resolvedValue.attributes = {
					recordId: record.recordId,
					objectApiName: record.objectApiName,
					...resolvedValue.attributes
				};
			}
			if (resolvedValue.type === 'standard__quickAction') {
				resolvedValue.state = { recordId: record.recordId, ...resolvedValue.state };
			}
			if (resolvedValue.type === 'standard__objectPage' && resolvedValue.state?.defaultFieldValues) {
				const defaultFieldValues = resolvedValue.state.defaultFieldValues;
				resolvedValue.state.defaultFieldValues =
					typeof defaultFieldValues === 'object' ? encodeDefaultFieldValues(defaultFieldValues) : defaultFieldValues;
			}
			return resolvedValue;
		}
		if (typeof value !== 'string') return value;
		return value.replaceAll('{recordId}', record.recordId || '').replaceAll('{objectApiName}', record.objectApiName || '');
	}

	handleCardKeydown(event) {
		if (event.key === 'Enter' || event.key === ' ') {
			event.preventDefault();
			this.navigateToRecord(event);
		}
	}

	previousPage() {
		if (this.hasPreviousPage) {
			this.currentPage = (this.currentPage - this.cardsPerView + this.records.length) % this.records.length;
		}
	}

	nextPage() {
		if (this.hasNextPage) {
			this.currentPage = (this.currentPage + this.cardsPerView) % this.records.length;
		}
	}

	getErrorMessage(error) {
		return error?.body?.message || 'Unable to load recently viewed records.';
	}

	showToast(title, message, variant) {
		this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
	}
}