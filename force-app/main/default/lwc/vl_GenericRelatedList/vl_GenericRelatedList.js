import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getRelatedRecords from '@salesforce/apex/VL_GenericRelatedListController.getRelatedRecords';

import NODATA_LABEL from '@salesforce/label/c.VL_NoData';

const DEFAULT_PAGE_SIZE = 20;
const VALID_PAGE_SIZES = [10, 20, 50, 100];

export default class VlGenericRelatedList extends LightningElement {
	_recordId;
	_relatedObjectApiName;
	_relationshipFieldApiName;
	_requestKey;
	_loadScheduled = false;
	_showHeader = true;
	@api title;
	@api iconName = 'standard:record';
	_fieldSet;
	_whereClause;
	_orderBy;
	_limitSize = 200;
	_showNewButton = false;
	_showExportButton = true;
	_showEditButton = false;
	_showDeleteButton = false;
	_objectInfo;
	columns = [];
	records = [];
	isLoading = false;
	isLoadingListViews = false;
	hasSelectedListView = true;

	nodata = NODATA_LABEL;

	@api
	get recordId() {
		return this._recordId;
	}
	set recordId(value) {
		this._recordId = value;
		this.scheduleLoadRelatedRecords();
	}

	@api
	get relatedObjectApiName() {
		return this._relatedObjectApiName;
	}
	set relatedObjectApiName(value) {
		this._relatedObjectApiName = value;
		this._objectInfo = undefined;
		this.resetData();
		this.scheduleLoadRelatedRecords();
	}

	@api
	get relationshipFieldApiName() {
		return this._relationshipFieldApiName;
	}
	set relationshipFieldApiName(value) {
		this._relationshipFieldApiName = value;
	}

	@api
	get showHeader() {
		return this._showHeader;
	}
	set showHeader(value) {
		this._showHeader = value !== false && value !== 'false';
	}

	@api
	get showNewButton() {
		return this._showNewButton;
	}
	set showNewButton(value) {
		this._showNewButton = value === true || value === 'true';
	}

	@api
	get showExportButton() {
		return this._showExportButton;
	}
	set showExportButton(value) {
		this._showExportButton = value !== false && value !== 'false';
	}

	@api
	get showEditButton() {
		return this._showEditButton;
	}
	set showEditButton(value) {
		this._showEditButton = value === true || value === 'true';
	}

	@api
	get showDeleteButton() {
		return this._showDeleteButton;
	}
	set showDeleteButton(value) {
		this._showDeleteButton = value === true || value === 'true';
	}

	@api
	get fieldSet() {
		return this._fieldSet;
	}
	set fieldSet(value) {
		this._fieldSet = value;
		this._requestKey = undefined;
		this.scheduleLoadRelatedRecords();
	}

	@api
	get whereClause() {
		return this._whereClause;
	}
	set whereClause(value) {
		this._whereClause = value;
		this._requestKey = undefined;
		this.scheduleLoadRelatedRecords();
	}

	@api
	get orderBy() {
		return this._orderBy;
	}
	set orderBy(value) {
		this._orderBy = value;
		this._requestKey = undefined;
		this.scheduleLoadRelatedRecords();
	}

	@api
	get limitSize() {
		return this._limitSize;
	}
	set limitSize(value) {
		this._limitSize = Number(value) || 200;
		this._requestKey = undefined;
		this.scheduleLoadRelatedRecords();
	}

	@api
	get pageSize() {
		return this._pageSize || DEFAULT_PAGE_SIZE;
	}
	set pageSize(value) {
		const parsedValue = Number(value);
		this._pageSize = VALID_PAGE_SIZES.includes(parsedValue) ? parsedValue : DEFAULT_PAGE_SIZE;
	}

	@wire(getObjectInfo, { objectApiName: '$_relatedObjectApiName' })
	wiredObjectInfo({ data }) {
		if (data) this._objectInfo = data;
	}

	get listTitle() {
		return this.title || `${this.relatedObjectApiName || 'Registros'} relacionados`;
	}

	get resultsLabel() {
		return this.listTitle;
	}

	get canCreateRecord() {
		return this._objectInfo?.createable === true;
	}

	get shouldShowNewButton() {
		return this.showNewButton && this.canCreateRecord;
	}

	get shouldShowEditButton() {
		return this.showEditButton && this._objectInfo?.updateable === true;
	}

	get shouldShowDeleteButton() {
		return this.showDeleteButton && this._objectInfo?.deletable === true;
	}

	scheduleLoadRelatedRecords() {
		if (this._loadScheduled) return;
		this._loadScheduled = true;
		Promise.resolve().then(() => {
			this._loadScheduled = false;
			this.loadRelatedRecords();
		});
	}

	loadRelatedRecords() {
		if (!this._recordId || !this._relatedObjectApiName || !this.fieldSet) return;
		const requestKey = `${this._recordId}|${this._relatedObjectApiName}|${this.fieldSet}|${this.whereClause}|${this.orderBy}|${this.limitSize}`;
		if (requestKey === this._requestKey) return;
		this._requestKey = requestKey;
		this.isLoading = true;

		getRelatedRecords({
			recordId: this._recordId,
			relatedObjectApiName: this._relatedObjectApiName,
			fieldSet: this.fieldSet,
			whereClause: this.whereClause,
			orderBy: this.orderBy,
			limitSize: this.limitSize
		})
			.then((result) => {
				this.columns = this.buildColumns(result?.fields || []);
				this.records = (result?.records || []).map((item) => this.buildRow(item));
			})
			.catch((error) => {
				this.records = [];
				this.handleError(error);
			})
			.finally(() => {
				this.isLoading = false;
			});
	}

	buildColumns(fields) {
		return fields.map((definition) => {
			const column = {
				fieldName: definition.fieldName,
				label: definition.label,
				type: this.getDatatableType(definition.dataType),
				dataType: definition.dataType,
				sortable: true
			};
			if (definition.isLookup || definition.fieldName === 'Name') return this.buildLinkColumn(column);
			if (definition.dataType === 'date') column.typeAttributes = { year: 'numeric', month: '2-digit', day: '2-digit' };
			if (definition.dataType === 'datetime') {
				column.type = 'date';
				column.typeAttributes = { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' };
			}
			return column;
		});
	}

	buildLinkColumn(column) {
		const sourceFieldName = column.fieldName;
		return {
			...column,
			fieldName: sourceFieldName === 'Name' ? 'recordUrl' : `${sourceFieldName}Url`,
			type: 'url',
			sortFieldName: sourceFieldName,
			typeAttributes: { label: { fieldName: sourceFieldName }, tooltip: { fieldName: sourceFieldName }, target: '_self' }
		};
	}

	buildRow(item) {
		const values = item.values || {};
		const row = { id: item.recordId, recordId: item.recordId, recordUrl: item.recordId ? `/${item.recordId}` : '' };
		Object.entries(values).forEach(([fieldName, value]) => {
			row[fieldName] = fieldName.endsWith('Url') ? this.normalizeRecordUrl(value) : this.normalizeValue(value);
		});
		return row;
	}

	normalizeRecordUrl(value) {
		const normalizedValue = this.normalizeValue(value).trim();
		if (!normalizedValue) return '';
		if (normalizedValue.startsWith('/') || /^https?:\/\//i.test(normalizedValue)) return normalizedValue;
		return /^([a-zA-Z0-9]{15}|[a-zA-Z0-9]{18})$/.test(normalizedValue) ? `/${normalizedValue}` : '';
	}

	normalizeValue(value) {
		if (value && typeof value === 'object') return value.value ?? value.label ?? '';
		return value ?? '';
	}

	getDatatableType(dataType) {
		return (
			{
				boolean: 'boolean',
				currency: 'currency',
				date: 'date',
				datetime: 'date',
				double: 'number',
				integer: 'number',
				percent: 'percent',
				email: 'email',
				phone: 'phone',
				url: 'url'
			}[dataType] || 'text'
		);
	}

	resetData() {
		this._requestKey = undefined;
		this.columns = [];
		this.records = [];
	}

	handleError(error) {
		this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.reduceError(error), variant: 'error' }));
	}

	handleRecordDelete(event) {
		const { recordId } = event.detail;
		this.records = this.records.filter((record) => record.recordId !== recordId);
	}

	handleRecordEdit() {
		this._requestKey = undefined;
		this.loadRelatedRecords();
	}

	reduceError(error) {
		return error?.body?.message || error?.message || 'No se pudieron cargar los registros relacionados';
	}
}