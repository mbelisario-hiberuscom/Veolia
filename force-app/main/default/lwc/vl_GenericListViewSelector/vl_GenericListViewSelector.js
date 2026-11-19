import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getListUi } from 'lightning/uiListApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getListViews from '@salesforce/apex/VL_GenericListViewSelectorController.getListViews';
import getFields from '@salesforce/apex/VL_GenericListViewSelectorController.getFields';
import getFieldValues from '@salesforce/apex/VL_GenericListViewSelectorController.getFieldValues';
import getSettings from '@salesforce/apex/VL_GenericListViewSelectorController.getSettings';
import saveSettings from '@salesforce/apex/VL_GenericListViewSelectorController.saveSettings';

import SEARCHRESULTS_LABEL from '@salesforce/label/c.VL_SearchResultsTitle';
import CLOSE_LABEL from '@salesforce/label/c.VL_Close';
import CREATE_LABEL from '@salesforce/label/c.VL_Create';

const PAGE_SIZE = 200;
const FIELD_LOAD_BATCH_SIZE = 200;
const MAX_PAGE_TOKEN = 2000;
const DEFAULT_PAGE_SIZE = 20;
const ERROR_MSG = 'Error: ';
const RECORD_URL_FIELD = 'recordUrl';
const RECENTLY_VIEWED_CARD_ACTIONS = [
	{
		label: 'Registrar llamada',
		name: 'logACall',
		iconName: 'utility:log_a_call',
		type: 'navigate',
		pageReference: {
			type: 'standard__quickAction',
			attributes: { apiName: 'Global.LogACall' },
			state: { recordId: '{recordId}' }
		}
	},
	{
		label: 'Nuevo evento',
		name: 'newEvent',
		iconName: 'utility:event',
		type: 'navigate',
		pageReference: {
			type: 'standard__objectPage',
			attributes: { objectApiName: 'Event', actionName: 'new' },
			state: {
				defaultFieldValues: { WhatId: '{recordId}', Subject: 'Seguimiento de cuenta' }
			}
		}
	},
	{
		label: 'Mostrar oportunidades',
		name: 'showOpportunityList',
		iconName: 'utility:list',
		type: 'screenFlow',
		flowName: 'ShowOpportunityList',
		flowInputVariables: [{ name: 'recordId', type: 'String', value: '{recordId}' }]
	}
];

export default class VlGenericListViewSelector extends NavigationMixin(LightningElement) {
	@api objectApiName;
	@api icon;
	@api title;
	@api subtitle;
	@api showRecentlyViewedRecords;
	@api recentlyViewedRecordLimit = 5;
	@api recentlyViewedFieldApiNames = 'CreatedDate';
	@api newRecordFlowApiName;
	recentlyViewedCardActions = RECENTLY_VIEWED_CARD_ACTIONS.length ? [] : RECENTLY_VIEWED_CARD_ACTIONS;
	@track listViews = [];
	@track allColumns = [];
	@track records = [];
	fieldDefinitions = [];
	savedColumnConfigurations = {};
	selectedListViewApiName;
	currentListViewDisplayColumns = [];
	pageToken;
	pageSize = DEFAULT_PAGE_SIZE;
	defaultSortDirection = 'asc';
	groupedDatatableGroupByFields = [''];
	loadCycle = 0;
	isLoading = false;
	isBackgroundLoading = false;
	isLoadingListViews = true;
	objectInfoData;
	isNewRecordFlowOpen = false;
	activeNewRecordFlowName;

	searResultsLabel = SEARCHRESULTS_LABEL;
	closeLabel = CLOSE_LABEL;
	createLabel = CREATE_LABEL;

	get shouldShowRecentlyViewedRecords() {
		return this.showRecentlyViewedRecords !== false && String(this.showRecentlyViewedRecords).trim().toLowerCase() !== 'false';
	}

	@wire(getObjectInfo, { objectApiName: '$objectApiName' })
	wiredObjectInfo({ data }) {
		if (data) {
			this.objectInfoData = data;
			this.normalizePicklistRows();
		}
	}

	connectedCallback() {
		Promise.all([
			getListViews({ objectApiName: this.objectApiName }),
			getFields({ objectApiName: this.objectApiName }),
			getSettings({ objectApiName: this.objectApiName })
		])
			.then(([listViews, fields, settings]) => {
				this.listViews = listViews || [];
				this.fieldDefinitions = [...(fields || [])].sort((left, right) => left.fieldApiName.localeCompare(right.fieldApiName));
				this.savedColumnConfigurations = this.parseColumnConfigurations(settings?.columnConfiguration);
				const savedPageSize = Number(settings?.pageSize);
				if (this.pageSizeOptions.some((option) => Number(option.value) === savedPageSize)) this.pageSize = savedPageSize;
				if (
					settings?.selectedListViewApiName &&
					this.listViews.some((item) => item.developerName === settings.selectedListViewApiName)
				) {
					this.selectedListViewApiName = settings.selectedListViewApiName;
					this.isLoading = true;
				}
				this.isLoadingListViews = false;
			})
			.catch((error) => {
				this.isLoadingListViews = false;
				this.showToast('Error', ERROR_MSG + this.reduceError(error), 'error');
			});
	}

	@wire(getListUi, {
		objectApiName: '$objectApiName',
		listViewApiName: '$selectedListViewApiName',
		pageSize: PAGE_SIZE,
		pageToken: '$pageToken'
	})
	wiredListView({ error, data }) {
		if (data?.info && data.records) {
			const displayColumns = data.info.displayColumns || [];
			const isInitialPage = !this.pageToken;
			const currentLoadCycle = this.loadCycle;
			if (isInitialPage) {
				this.currentListViewDisplayColumns = displayColumns;
				this.allColumns = this.buildColumns(displayColumns);
			}
			const pageRows = this.buildRows(data.records.records || []);
			this.records = isInitialPage ? pageRows : [...this.records, ...pageRows];
			this.normalizePicklistRows();
			const fieldLoadPromise = this.loadVisibleAdditionalFields(displayColumns, pageRows);
			fieldLoadPromise.catch((fieldLoadError) => {
				this.showToast('Error', ERROR_MSG + this.reduceError(fieldLoadError), 'error');
			});
			if (isInitialPage) {
				fieldLoadPromise.finally(() => {
					if (currentLoadCycle === this.loadCycle) this.isLoading = false;
				});
			}
			if (data.records.nextPageToken && this.canRequestPage(data.records.nextPageToken)) {
				this.isBackgroundLoading = true;
				this.pageToken = data.records.nextPageToken;
				return;
			}
			if (!isInitialPage) this.isLoading = false;
			this.isBackgroundLoading = false;
		} else if (error && this.selectedListViewApiName) {
			this.isLoading = false;
			this.isBackgroundLoading = false;
			this.showToast('Error', ERROR_MSG + this.reduceError(error), 'error');
		}
	}

	canRequestPage(pageToken) {
		const numericPageToken = Number(pageToken);
		return !Number.isFinite(numericPageToken) || numericPageToken <= MAX_PAGE_TOKEN;
	}

	get listViewButtons() {
		return this.listViews.map((item) => ({
			...item,
			buttonClass: `list-view-button${this.selectedListViewApiName === item.developerName ? ' is-selected' : ''}`,
			isSelected: this.selectedListViewApiName === item.developerName,
			isLoading: this.isBackgroundLoading && this.selectedListViewApiName === item.developerName
		}));
	}
	get hasListViews() {
		return this.listViews.length > 0;
	}
	get hasSelectedListView() {
		return !!this.selectedListViewApiName;
	}
	get objectLabel() {
		return this.objectInfoData?.label || this.objectApiName || 'registro';
	}
	get canCreateRecord() {
		return this.objectInfoData?.createable === true;
	}
	get createRecordLabel() {
		return this.createLabel + ' ' + this.objectLabel;
	}
	get columns() {
		return this.allColumns
			.filter((column) => column.visible)
			.map((column) => {
				if (this.getFieldKey(column.fieldName) === 'name') return this.buildLinkColumn(column, RECORD_URL_FIELD);
				if (column.isLookup) return this.buildLinkColumn(column, `${column.fieldName}Url`);
				return column;
			});
	}
	get pageSizeOptions() {
		return [
			{ label: '10', value: '10' },
			{ label: '20', value: '20' },
			{ label: '50', value: '50' },
			{ label: '100', value: '100' }
		];
	}
	handleListViewButtonClick(event) {
		const value = event.currentTarget.dataset.listViewApiName;
		if (value && value !== this.selectedListViewApiName) this.handleListViewChange(value);
	}
	handleListViewChange(value) {
		this.selectedListViewApiName = value;
		this.records = [];
		this.allColumns = [];
		this.pageToken = undefined;
		this.loadCycle += 1;
		this.isLoading = true;
		this.isBackgroundLoading = false;
		this.persistSelectedListView(value);
	}
	handleNewRecord() {
		const flowApiName = String(this.newRecordFlowApiName || '').trim();
		if (flowApiName) {
			this.activeNewRecordFlowName = flowApiName;
			this.isNewRecordFlowOpen = true;
			return;
		}
		this[NavigationMixin.Navigate]({
			type: 'standard__objectPage',
			attributes: {
				objectApiName: this.objectApiName,
				actionName: 'new'
			}
		});
	}
	closeNewRecordFlow() {
		this.isNewRecordFlowOpen = false;
		this.activeNewRecordFlowName = undefined;
	}
	handleNewRecordFlowStatusChange(event) {
		if (['FINISHED', 'FINISHED_SCREEN'].includes(event.detail.status)) this.closeNewRecordFlow();
	}
	handlePageSizeChange(event) {
		this.pageSize = Number(event.detail.value);
		this.savePreferences(this.getSavedColumnConfiguration()).catch((error) => this.showToast('Error', this.reduceError(error), 'error'));
	}
	handleColumnSave(event) {
		const { columns, isReset } = event.detail;
		this.allColumns = isReset ? this.buildColumns(this.currentListViewDisplayColumns, false) : this.cloneColumns(columns);
		this.isLoading = true;
		Promise.all([
			this.loadVisibleAdditionalFields(this.currentListViewDisplayColumns),
			this.savePreferences(isReset ? '' : this.serializeColumnConfiguration(this.allColumns))
		])
			.then(() => undefined)
			.catch((error) => this.showToast('Error', ERROR_MSG + this.reduceError(error), 'error'))
			.finally(() => {
				this.isLoading = false;
			});
	}

	buildColumns(displayColumns, applySavedConfiguration = true) {
		const definitions = new Map(this.fieldDefinitions.map((field) => [this.getFieldKey(field.fieldApiName), field]));
		const selected = displayColumns
			.map((column) => this.makeColumn(this.resolveFieldName(column.fieldApiName, definitions), column.label, true, definitions))
			.filter(Boolean);
		const selectedKeys = new Set(selected.map((column) => this.getFieldKey(column.fieldName)));
		const hidden = this.fieldDefinitions
			.filter((field) => !selectedKeys.has(this.getFieldKey(field.fieldApiName)))
			.map((field) => this.makeColumn(field.fieldApiName, field.label, false, definitions));
		const columns = [...new Map([...selected, ...hidden].map((column) => [this.getFieldKey(column.fieldName), column])).values()];
		return applySavedConfiguration ? this.applySavedColumnConfiguration(columns) : columns;
	}
	makeColumn(fieldName, label, visible, definitions) {
		const definition = definitions.get(this.getFieldKey(fieldName));
		const datatableType = definition ? this.getDatatableType(definition.type, definition.customDataType) : null;
		return definition
			? {
					fieldName: definition.fieldApiName,
					label: label || definition.label,
					type: datatableType,
					typeAttributes: this.getTypeAttributes(definition.type, definition.customDataType, definition.fieldApiName),
					customDataType: definition.customDataType,
					colorByValue: definition.colorByValue,
					isLookup: definition.type === 'reference',
					dataType: definition.type,
					visible,
					isInListView: visible,
					sortable: true
				}
			: null;
	}
	getDatatableType(type, customDataType) {
		if (customDataType) {
			return customDataType.charAt(0).toUpperCase() + customDataType.slice(1);
		}
		return (
			{
				boolean: 'boolean',
				currency: 'currency',
				date: 'date',
				datetime: 'date',
				double: 'number',
				int: 'number',
				percent: 'percent',
				email: 'email',
				phone: 'phone',
				url: 'url'
			}[type] || 'text'
		);
	}
	getTypeAttributes(type, customDataType, fieldName) {
		if (customDataType?.toLowerCase() === 'picklistcolor') {
			return { colorValue: { fieldName: `${fieldName}Color` } };
		}
		if (type === 'date') {
			return { year: 'numeric', month: '2-digit', day: '2-digit' };
		}
		if (type === 'datetime') {
			return { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' };
		}
		return undefined;
	}
	getFieldKey(value) {
		return (value || '').trim().toLowerCase();
	}
	resolveFieldName(fieldName, definitions) {
		const normalizedFieldName = this.getFieldKey(fieldName);
		if (definitions.has(normalizedFieldName)) return definitions.get(normalizedFieldName).fieldApiName;
		const relationshipName = normalizedFieldName.includes('.')
			? normalizedFieldName.split('.')[0]
			: normalizedFieldName.endsWith('_name')
				? normalizedFieldName.slice(0, -5)
				: '';
		const definition = this.fieldDefinitions.find((field) => this.getFieldKey(field.relationshipName) === relationshipName);
		return definition?.fieldApiName || fieldName;
	}
	buildRows(records) {
		const groupedFieldKeys = new Set(this.groupedDatatableGroupByFields.map((fieldName) => this.getFieldKey(fieldName)));
		const rowColumns = this.allColumns.filter((column) => column.visible || groupedFieldKeys.has(this.getFieldKey(column.fieldName)));
		return records.map((record, index) => {
			const row = { id: record.id || `row-${index}`, recordId: record.id, recordUrl: record.id ? `/${record.id}` : '' };
			rowColumns.forEach((column) => {
				const field = this.getRecordField(record, column.fieldName);
				if (column.customDataType?.toLowerCase() === 'picklistcolor') {
					const value = this.getRawCellValue(field, column);
					const label = this.getCellDisplayValue(field, column.fieldName);
					row[column.fieldName] = label || value;
					row[`${column.fieldName}Color`] = column.colorByValue?.[String(value)] || 'neutral';
				} else {
					row[column.fieldName] = column.isLookup ? this.getLookupDisplayValue(field) : this.getCellValue(field, column);
				}
				if (column.isLookup) row[`${column.fieldName}Url`] = this.getLookupUrl(field);
			});
			return row;
		});
	}
	getRecordField(record, fieldName) {
		const fields = record?.fields || {};
		if (fields[fieldName]) return fields[fieldName];
		const fieldKey = this.getFieldKey(fieldName);
		const matchingEntry = Object.entries(fields).find(([key]) => this.getFieldKey(key) === fieldKey);
		return matchingEntry?.[1];
	}
	normalizePicklistRows() {
		if (!this.records.length) return;
		const picklistColumns = this.allColumns.filter((column) => column.dataType === 'picklist' || column.dataType === 'multipicklist');
		if (!picklistColumns.length) return;
		this.records = this.records.map((row) => {
			const normalizedRow = { ...row };
			picklistColumns.forEach((column) => {
				normalizedRow[column.fieldName] = this.getCellDisplayValue({ value: row[column.fieldName] }, column.fieldName);
			});
			return normalizedRow;
		});
	}
	getColumnByFieldName(fieldName) {
		return this.allColumns.find((column) => this.getFieldKey(column.fieldName) === this.getFieldKey(fieldName));
	}
	getCellValue(field, column) {
		if (!field) return column.dataType === 'boolean' ? false : '';
		if (column.isLookup) return this.removeMarkdownLink(field.displayValue ?? field.value ?? '');
		if (column.dataType === 'picklist' || column.dataType === 'multipicklist') return this.getCellDisplayValue(field, column.fieldName);
		return this.getRawCellValue(field, column);
	}
	getRawCellValue(field, column) {
		if (!field) return column.dataType === 'boolean' ? false : '';
		let value = field.value ?? field.displayValue ?? '';
		if (value && typeof value === 'object' && Object.prototype.hasOwnProperty.call(value, 'value')) value = value.value;
		if (column.dataType === 'boolean') return value === true || value === 'true';
		return this.removeMarkdownLink(value);
	}
	getCellDisplayValue(field, fieldName) {
		if (!field) return '';
		const picklistLabel = this.getPicklistLabel(fieldName, field.value);
		let displayValue = picklistLabel || field.displayValue;
		if (displayValue == null && field.value && typeof field.value === 'object') {
			displayValue = field.value.displayValue ?? field.value.label ?? field.value.value;
		}
		displayValue ??= field.value ?? '';
		if (displayValue && typeof displayValue === 'object' && Object.prototype.hasOwnProperty.call(displayValue, 'value')) {
			displayValue = displayValue.displayValue ?? displayValue.label ?? displayValue.value;
		}
		return this.removeMarkdownLink(displayValue);
	}
	getLookupDisplayValue(field) {
		if (!field) return '';
		const rawValue = this.getFieldValue(field.value);
		const displayValue = this.removeMarkdownLink(field.displayValue ?? '');
		return displayValue && displayValue !== rawValue ? displayValue : '';
	}
	getLookupUrl(field) {
		const lookupId = this.getFieldValue(field?.value);
		return lookupId ? `/${lookupId}` : '';
	}
	getFieldValue(value) {
		if (value && typeof value === 'object') return value.value ?? value.id ?? '';
		return value ?? '';
	}
	getPicklistLabel(fieldName, value) {
		const rawValue = value && typeof value === 'object' ? value.value : value;
		const fieldInfo = Object.entries(this.objectInfoData?.fields || {}).find(
			([key]) => this.getFieldKey(key) === this.getFieldKey(fieldName)
		)?.[1];
		if (!fieldInfo?.picklistValues) return '';
		return String(rawValue || '')
			.split(';')
			.map((entry) => fieldInfo.picklistValues.find((item) => String(item.value) === entry)?.label || entry)
			.join('; ');
	}
	buildLinkColumn(column, urlFieldName) {
		return {
			...column,
			sortFieldName: column.fieldName,
			fieldName: urlFieldName,
			type: 'url',
			typeAttributes: { label: { fieldName: column.fieldName }, tooltip: { fieldName: column.fieldName }, target: '_self' }
		};
	}
	loadVisibleAdditionalFields(displayColumns, recordRows = this.records) {
		const names = this.allColumns
			.filter(
				(column) =>
					column.visible && !displayColumns.some((item) => this.getFieldKey(item.fieldApiName) === this.getFieldKey(column.fieldName))
			)
			.map((column) => column.fieldName);
		const lookups = this.allColumns.filter((column) => column.visible && column.isLookup).map((column) => column.fieldName);
		const picklists = this.allColumns
			.filter((column) => column.visible && (column.dataType === 'picklist' || column.dataType === 'multipicklist'))
			.map((column) => column.fieldName);
		return this.loadFieldValuesInBatches([...names, ...lookups, ...picklists, ...this.groupedDatatableGroupByFields, 'Name'], recordRows);
	}
	loadFieldValuesInBatches(fieldApiNames, recordRows) {
		const requestId = this.loadCycle;
		const batches = [];
		for (let index = 0; index < recordRows.length; index += FIELD_LOAD_BATCH_SIZE) {
			batches.push(recordRows.slice(index, index + FIELD_LOAD_BATCH_SIZE));
		}
		return batches.reduce(
			(promise, batch) => promise.then(() => this.loadFieldValues(fieldApiNames, batch, requestId)),
			Promise.resolve()
		);
	}
	loadFieldValues(fieldApiNames, recordRows, requestId) {
		const ids = recordRows.map((row) => row.recordId).filter(Boolean);
		if (!ids.length) return Promise.resolve();
		return getFieldValues({ objectApiName: this.objectApiName, recordIds: ids, fieldApiNames: [...new Set(fieldApiNames)] }).then(
			(values) => {
				if (requestId !== this.loadCycle) return;
				const byId = new Map((values || []).map((item) => [item.recordId, item.values || {}]));
				this.records = this.records.map((row) => {
					const updatedRow = {
						...row,
						...Object.entries(byId.get(row.recordId) || {}).reduce((result, [key, value]) => {
							const isUrl = key.endsWith('__url');
							const fieldName = isUrl ? key.slice(0, -5) : key;
							const column = this.getColumnByFieldName(fieldName);
							result[isUrl ? `${fieldName}Url` : fieldName] = isUrl
								? value
									? `/${value}`
									: ''
								: column?.dataType === 'picklist' || column?.dataType === 'multipicklist'
									? this.getCellDisplayValue({ value }, fieldName)
									: value;
							return result;
						}, {})
					};
					this.allColumns
						.filter((column) => column.customDataType?.toLowerCase() === 'picklistcolor')
						.forEach((column) => {
							updatedRow[`${column.fieldName}Color`] = column.colorByValue?.[String(updatedRow[column.fieldName])] || 'neutral';
						});
					return updatedRow;
				});
			}
		);
	}
	cloneColumns(columns) {
		return (columns || []).map((column) => ({ ...column }));
	}
	applySavedColumnConfiguration(columns) {
		const saved = this.getSavedColumnConfiguration();
		if (!saved) return columns;
		const state = this.getSavedColumnState(saved);
		const byName = new Map(state.map((item) => [this.getFieldKey(item.fieldName), item]));
		return columns
			.map((column, index) => ({
				...column,
				visible: byName.has(this.getFieldKey(column.fieldName)),
				order: byName.has(this.getFieldKey(column.fieldName))
					? byName.get(this.getFieldKey(column.fieldName)).order
					: state.length + index
			}))
			.sort((left, right) => left.order - right.order)
			.map((column) => {
				const columnWithoutOrder = { ...column };
				delete columnWithoutOrder.order;
				return columnWithoutOrder;
			});
	}
	getSavedColumnState(configuration) {
		const value = configuration.startsWith('v2:') ? configuration.slice(3) : configuration;
		return value
			.split(',')
			.filter(Boolean)
			.map((fieldKey, order) => ({
				fieldName: fieldKey.startsWith('!') ? fieldKey.slice(1) : fieldKey,
				visible: !fieldKey.startsWith('!'),
				order
			}));
	}
	getSavedColumnConfiguration() {
		return this.savedColumnConfigurations[this.selectedListViewApiName] || '';
	}
	parseColumnConfigurations(value) {
		if (!value) return {};
		return value.split('|').reduce((result, item) => {
			const separator = item.indexOf('~');
			if (separator > 0) result[item.slice(0, separator)] = item.slice(separator + 1);
			return result;
		}, {});
	}
	serializeColumnConfiguration(columns = this.allColumns) {
		return `v2:${columns
			.filter((column) => column.visible)
			.map((column) => column.fieldName)
			.join(',')}`;
	}
	persistSelectedListView() {
		this.savePreferences(this.getSavedColumnConfiguration()).catch((error) => this.showToast('Error', this.reduceError(error), 'error'));
	}
	savePreferences(configuration) {
		const configurations = { ...this.savedColumnConfigurations };
		if (configuration) configurations[this.selectedListViewApiName] = configuration;
		else delete configurations[this.selectedListViewApiName];
		return saveSettings({
			objectApiName: this.objectApiName,
			selectedListViewApiName: this.selectedListViewApiName,
			pageSize: this.pageSize,
			columnConfiguration: Object.entries(configurations)
				.map(([key, value]) => `${key}~${value}`)
				.join('|')
		}).then(() => {
			this.savedColumnConfigurations = configurations;
		});
	}
	removeMarkdownLink(value) {
		const match = String(value).match(/^\[([^\]]*)\]\([^)]*\)$/);
		return match ? match[1] : value;
	}
	reduceError(error) {
		return error?.body?.message || error?.message || JSON.stringify(error);
	}
	showToast(title, message, variant) {
		this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
	}
}