import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import LightningConfirm from 'lightning/confirm';
import { deleteRecord } from 'lightning/uiRecordApi';
import SHEETJS from '@salesforce/resourceUrl/VL_SheetJS';

import CLOSE_LABEL from '@salesforce/label/c.VL_Close';
import SEARCHPLACEHOLDER_LABEL from '@salesforce/label/c.VL_SearchPlaceholder';
import NEWRECORD_LABEL from '@salesforce/label/c.VL_NewRecord';
import EXPORT_LABEL from '@salesforce/label/c.VL_Export';
import CONFIGURECOLUMNS_LABEL from '@salesforce/label/c.VL_ConfigureColumns';
import AVAILABLES_LABEL from '@salesforce/label/c.VL_Availables';
import SELECTED_LABEL from '@salesforce/label/c.VL_Selected';
import NODATA_LABEL from '@salesforce/label/c.VL_NoData';
import RESET_LABEL from '@salesforce/label/c.VL_Reset';
import CANCEL_LABEL from '@salesforce/label/c.VL_Cancel';
import SAVE_LABEL from '@salesforce/label/c.VL_Save';
import FIRSTPAGE_LABEL from '@salesforce/label/c.VL_FirstPage';
import LASTPAGE_LABEL from '@salesforce/label/c.VL_LastPage';
import NEXTPAGE_LABEL from '@salesforce/label/c.VL_NextPage';
import PREVIOUSPAGE_LABEL from '@salesforce/label/c.VL_PreviousPage';
import EDIT_LABEL from '@salesforce/label/c.VL_Edit';
import DELETE_LABEL from '@salesforce/label/c.VL_Delete';

const DEFAULT_PAGE_SIZE = 20;
const COMPACT_TOOLBAR_BREAKPOINT = 775;
const PAGE_SIZE_OPTIONS = [
	{ label: '10', value: '10' },
	{ label: '20', value: '20' },
	{ label: '50', value: '50' },
	{ label: '100', value: '100' }
];

export default class VlGenericPaginatedDatatable extends NavigationMixin(LightningElement) {
	_data = [];
	_pageSize = DEFAULT_PAGE_SIZE;
	_columnOptions = [];
	_searchTerm = '';
	draftSelectedValues = [];
	currentPage = 1;
	sortDirection = 'asc';
	sortedBy;
	_defaultSortDirection = 'asc';
	isColumnPanelOpen = false;
	isColumnsDirty = false;
	isColumnsReset = false;
	sheetJsInitialized = false;
	isPageSizeMenuOpen = false;
	isCompactToolbar = false;
	_resizeObserver;
	_resizeObserverInitialized = false;

	closeLabel = CLOSE_LABEL;
	searchPlaceHolderLabel = SEARCHPLACEHOLDER_LABEL;
	newRecordLabel = NEWRECORD_LABEL;
	exportLabel = EXPORT_LABEL;
	configureColumns = CONFIGURECOLUMNS_LABEL;
	availables = AVAILABLES_LABEL;
	selectedLabel = SELECTED_LABEL;
	noDataLabel = NODATA_LABEL;
	resetLabel = RESET_LABEL;
	cancelLabel = CANCEL_LABEL;
	saveLabel = SAVE_LABEL;
	firstPageLabel = FIRSTPAGE_LABEL;
	lastPageLabel = LASTPAGE_LABEL;
	nextPageLabel = NEXTPAGE_LABEL;
	previousPageLabel = PREVIOUSPAGE_LABEL;
	editLabel = EDIT_LABEL;
	deleteLabel = DELETE_LABEL;

	@api columns = [];
	@api resultsLabel = 'Resultados de la búsqueda';
	@api headerTitle;
	@api headerIconName;
	@api showHeader;
	_showNewButton = false;
	_showExportButton = true;
	_showEditButton = false;
	_showDeleteButton = false;
	@api isLoading = false;
	@api isLoadingListViews = false;
	@api hasSelectedListView = false;
	@api objectApiName;
	@api recordId;
	@api relationshipFieldApiName;
	@api
	get searchTerm() {
		return this._searchTerm;
	}
	set searchTerm(value) {
		this._searchTerm = value || '';
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
	@api exportDisabled = false;
	@api emptyStateLoadingLabel = 'Loading list views...';
	@api emptyStateDataLabel = 'No data available';
	@api emptyStateSelectionLabel = 'Select a list view to display data';
	@api
	get defaultSortDirection() {
		return this._defaultSortDirection;
	}
	set defaultSortDirection(value) {
		this._defaultSortDirection = value === 'desc' ? 'desc' : 'asc';
		if (!this.sortedBy) this.sortDirection = this._defaultSortDirection;
	}

	@api
	get columnOptions() {
		return this._columnOptions;
	}
	set columnOptions(value) {
		this._columnOptions = Array.isArray(value) ? value : [];
		if (!this.isColumnPanelOpen) this.draftSelectedValues = this.getVisibleFieldNames(this._columnOptions);
	}

	@api
	get data() {
		return this._data;
	}
	set data(value) {
		const nextData = Array.isArray(value) ? value : [];
		const previousLength = this._data.length;
		this._data = nextData;
		if (!previousLength || !nextData.length || nextData.length < previousLength) {
			this.currentPage = 1;
			return;
		}
		const lastPage = Math.max(1, Math.ceil(nextData.length / this._pageSize));
		if (this.currentPage > lastPage) this.currentPage = lastPage;
	}

	@api
	get pageSize() {
		return this._pageSize;
	}
	set pageSize(value) {
		const normalizedValue = Number(value);
		const nextPageSize = PAGE_SIZE_OPTIONS.some((option) => Number(option.value) === normalizedValue)
			? normalizedValue
			: DEFAULT_PAGE_SIZE;
		if (this._pageSize !== nextPageSize) this.currentPage = 1;
		this._pageSize = nextPageSize;
	}

	get pagedData() {
		return this.filteredData.slice((this.currentPage - 1) * this._pageSize, this.currentPage * this._pageSize);
	}
	get totalPages() {
		return Math.max(1, Math.ceil(this.filteredData.length / this._pageSize));
	}
	get pageStart() {
		return this.filteredData.length ? (this.currentPage - 1) * this._pageSize + 1 : 0;
	}
	get pageEnd() {
		return Math.min(this.currentPage * this._pageSize, this.filteredData.length);
	}
	get isFirstPage() {
		return this.currentPage <= 1;
	}
	get isLastPage() {
		return this.currentPage >= this.totalPages;
	}
	get showPagination() {
		return this.filteredData.length > this._pageSize;
	}
	get pageSizeValue() {
		return String(this._pageSize);
	}
	get pageSizeOptions() {
		return PAGE_SIZE_OPTIONS.map((option) => ({ ...option, isSelected: option.value === this.pageSizeValue }));
	}
	get paginationSummary() {
		return this.filteredData.length ? `${this.pageStart}-${this.pageEnd} de ${this.filteredData.length}` : '0 resultados';
	}
	get pageList() {
		if (this.totalPages <= 1) return [];
		let pages;
		if (this.totalPages <= 10) pages = Array.from({ length: this.totalPages }, (_, index) => index + 1);
		else if (this.currentPage <= 5) pages = [1, 2, 3, 4, 5, 6, '...', this.totalPages];
		else if (this.currentPage > this.totalPages - 5) {
			pages = [
				1,
				'...',
				this.totalPages - 5,
				this.totalPages - 4,
				this.totalPages - 3,
				this.totalPages - 2,
				this.totalPages - 1,
				this.totalPages
			];
		} else {
			pages = [1, '...', this.currentPage - 1, this.currentPage, this.currentPage + 1, '...', this.totalPages];
		}
		return pages.map((page, index) => ({
			key: `${page}-${index}`,
			label: page,
			page: page === '...' ? '' : page,
			isEllipsis: page === '...',
			className: `item-pagination slds-p-horizontal_x-small${page === '...' ? ' ellipsis' : ''}${page === this.currentPage ? ' selected' : ''}`
		}));
	}
	get hasData() {
		return this.filteredData.length > 0;
	}
	get hasSourceData() {
		return this._data.length > 0;
	}
	get resultsHeading() {
		return `${this.resultsLabel} (${this.filteredData.length})`;
	}
	get displayHeaderTitle() {
		return this.headerTitle || this.resultsLabel;
	}
	get showResultsHeader() {
		return this.showHeader !== false && String(this.showHeader).trim().toLowerCase() !== 'false';
	}
	get showHeaderRow() {
		return this.showResultsHeader || this.hasSourceData || this.showNewButton;
	}
	get showHeaderIcon() {
		return !!this.headerIconName;
	}
	get filteredData() {
		const normalizedSearchTerm = this._searchTerm.trim().toLowerCase();
		if (!normalizedSearchTerm) return this._data;
		const searchableColumns = (this._columnOptions.length ? this._columnOptions : this.columns).filter(
			(column) => column.visible !== false
		);
		return this._data.filter((row) =>
			searchableColumns.some((column) => this.getRowText(this.getSearchValue(row, column)).toLowerCase().includes(normalizedSearchTerm))
		);
	}
	get showColumnConfiguration() {
		return this._columnOptions.length > 0;
	}
	get columnListboxOptions() {
		return this._columnOptions
			.map((column) => ({ label: column.label, value: column.fieldName }))
			.sort((left, right) => left.label.localeCompare(right.label, undefined, { sensitivity: 'base', numeric: true }));
	}
	get isSaveColumnsDisabled() {
		return this.isLoading || !this.isColumnsDirty;
	}
	get isExportDisabled() {
		return this.isLoading || this.exportDisabled || !this.filteredData.length || !this.sheetJsInitialized;
	}
	get shouldShowExportButton() {
		return this.showExportButton && this.filteredData.length > 0;
	}
	get rowActions() {
		const actions = [];
		if (this.showEditButton) actions.push({ label: this.editLabel, name: 'edit', iconName: 'utility:edit' });
		if (this.showDeleteButton) actions.push({ label: this.deleteLabel, name: 'delete', iconName: 'utility:delete' });
		return actions;
	}
	get renderedColumns() {
		if (!this.rowActions.length) return this.columns;
		return [...this.columns, { type: 'action', typeAttributes: { rowActions: this.rowActions } }];
	}
	get showToolbar() {
		return this.hasSourceData || this.showNewButton;
	}
	get searchInputClass() {
		return `search-input${this.isCompactToolbar ? ' search-input-compact' : ''}`;
	}
	get resultsHeaderClass() {
		return `results-header${this.isCompactToolbar ? ' results-header-compact' : ''}`;
	}
	get toolbarClass() {
		return `toolbar${this.isCompactToolbar ? ' toolbar-compact' : ''}`;
	}
	get toolbarActionsClass() {
		return `toolbar-actions${this.isCompactToolbar ? ' toolbar-actions-compact' : ''}`;
	}

	handleRowAction(event) {
		const { action, row } = event.detail;
		const recordId = row.recordId || row.id;
		if (action.name === 'edit') {
			this[NavigationMixin.Navigate]({
				type: 'standard__recordPage',
				attributes: { recordId, actionName: 'edit' }
			});
			this.dispatchEvent(new CustomEvent('recordedit', { detail: { recordId } }));
		} else if (action.name === 'delete') {
			this.handleDelete(recordId);
		}
	}

	async handleDelete(recordId) {
		const confirmed = await LightningConfirm.open({
			message: '¿Está seguro de que desea eliminar este registro?',
			variant: 'header',
			theme: 'warning',
			label: 'Confirmar eliminación'
		});
		if (!confirmed) return;
		try {
			await deleteRecord(recordId);
			this._data = this._data.filter((row) => (row.recordId || row.id) !== recordId);
			this.dispatchEvent(new CustomEvent('recorddelete', { detail: { recordId } }));
		} catch (error) {
			this.showToast('Error', this.reduceError(error), 'error');
		}
	}

	handleNewRecord() {
		const defaultFieldValues =
			this.recordId && this.relationshipFieldApiName
				? encodeDefaultFieldValues({ [this.relationshipFieldApiName]: this.recordId })
				: undefined;
		this[NavigationMixin.Navigate]({
			type: 'standard__objectPage',
			attributes: {
				objectApiName: this.objectApiName,
				actionName: 'new'
			},
			...(defaultFieldValues ? { state: { defaultFieldValues } } : {})
		});
	}

	renderedCallback() {
		this.initializeResizeObserver();
		if (this.sheetJsInitialized) return;
		this.sheetJsInitialized = true;
		loadScript(this, SHEETJS).catch((error) => {
			this.sheetJsInitialized = false;
			this.showToast('Error', this.reduceError(error), 'error');
		});
	}
	disconnectedCallback() {
		this._resizeObserver?.disconnect();
	}
	initializeResizeObserver() {
		if (this._resizeObserverInitialized || typeof ResizeObserver === 'undefined') return;
		const container = this.template.querySelector('.table-container');
		if (!container) return;
		this._resizeObserverInitialized = true;
		this._resizeObserver = new ResizeObserver(([entry]) => {
			const nextIsCompact = entry.contentRect.width < COMPACT_TOOLBAR_BREAKPOINT;
			if (this.isCompactToolbar !== nextIsCompact) this.isCompactToolbar = nextIsCompact;
		});
		this._resizeObserver.observe(container);
	}

	handleSort(event) {
		const { fieldName, sortDirection } = event.detail;
		const column = this.getSortColumn(fieldName);
		if (!column) return;
		this._data = this.sortRows(this._data, column, sortDirection === 'asc');
		this.sortDirection = sortDirection;
		this.sortedBy = fieldName;
		this.currentPage = 1;
	}
	handleSearch(event) {
		this._searchTerm = event.detail.value || '';
		this.currentPage = 1;
	}
	togglePageSizeMenu() {
		this.isPageSizeMenuOpen = !this.isPageSizeMenuOpen;
	}
	handlePageSizeOptionClick(event) {
		this.handlePageSizeChange({ detail: { value: event.currentTarget.dataset.value } });
		this.isPageSizeMenuOpen = false;
	}
	handleExport() {
		if (this.isExportDisabled || !window.XLSX) return;
		try {
			const exportColumns = (this._columnOptions.length ? this._columnOptions : this.columns).filter(
				(column) => column.visible !== false
			);
			const data = [
				exportColumns.map((column) => column.label),
				...this.filteredData.map((row) => exportColumns.map((column) => this.getRowText(this.getSearchValue(row, column))))
			];
			const worksheet = window.XLSX.utils.aoa_to_sheet(data);
			worksheet['!cols'] = this.autoFitColumns(data);
			worksheet['!autofilter'] = { ref: `A1:${window.XLSX.utils.encode_col(exportColumns.length - 1)}1` };
			const workbook = window.XLSX.utils.book_new();
			window.XLSX.utils.book_append_sheet(workbook, worksheet, this.objectApiName || 'Datos');
			const blob = new Blob([window.XLSX.write(workbook, { bookType: 'xlsx', type: 'array' })], {
				type: 'application/octet-stream'
			});
			const url = URL.createObjectURL(blob);
			const link = document.createElement('a');
			link.href = url;
			link.download = `${this.objectApiName || 'datos'}_${new Date().toISOString().slice(0, 10)}.xlsx`;
			link.click();
			URL.revokeObjectURL(url);
		} catch (error) {
			this.showToast('Error', this.reduceError(error), 'error');
		}
	}
	toggleColumnPanel() {
		if (this.isColumnPanelOpen) {
			this.handleCancelColumns();
			return;
		}
		this.draftSelectedValues = this.getVisibleFieldNames(this._columnOptions);
		this.isColumnsDirty = false;
		this.isColumnsReset = false;
		this.isColumnPanelOpen = true;
	}
	handleColumnListboxChange(event) {
		this.draftSelectedValues = [...event.detail.value];
		this.isColumnsReset = false;
		this.isColumnsDirty = true;
	}
	handleResetColumns() {
		this.draftSelectedValues = this._columnOptions.filter((column) => column.isInListView).map((column) => column.fieldName);
		this.isColumnsReset = true;
		this.isColumnsDirty = true;
	}
	handleCancelColumns() {
		this.draftSelectedValues = this.getVisibleFieldNames(this._columnOptions);
		this.isColumnsReset = false;
		this.isColumnsDirty = false;
		this.isColumnPanelOpen = false;
	}
	handleSaveColumns() {
		this.dispatchEvent(
			new CustomEvent('columnsave', {
				detail: { columns: this.buildColumnsFromSelection(), isReset: this.isColumnsReset }
			})
		);
		this.isColumnPanelOpen = false;
		this.isColumnsDirty = false;
		this.isColumnsReset = false;
	}
	handleFirstPage() {
		this.currentPage = 1;
	}
	handlePreviousPage() {
		if (!this.isFirstPage) this.currentPage--;
	}
	handleNextPage() {
		if (!this.isLastPage) this.currentPage++;
	}
	handleLastPage() {
		this.currentPage = this.totalPages;
	}
	handlePageChange(event) {
		const page = Number(event.currentTarget.dataset.page);
		if (page >= 1 && page <= this.totalPages) this.currentPage = page;
	}
	handlePageSizeChange(event) {
		const normalizedValue = Number(event.detail.value);
		this._pageSize = PAGE_SIZE_OPTIONS.some((option) => Number(option.value) === normalizedValue) ? normalizedValue : DEFAULT_PAGE_SIZE;
		this.currentPage = 1;
		this.dispatchEvent(new CustomEvent('pagesizechange', { detail: { value: this._pageSize } }));
	}
	handleKeyDownPagination(event) {
		if (event.key === 'Enter' || event.key === ' ') {
			event.preventDefault();
			event.currentTarget.click();
		}
	}
	cloneColumns(columns) {
		return (columns || []).map((column) => ({ ...column }));
	}
	getVisibleFieldNames(columns) {
		return (columns || []).filter((column) => column.visible !== false).map((column) => column.fieldName);
	}
	buildColumnsFromSelection() {
		const selectedValues = this.draftSelectedValues || [];
		const columnsByField = new Map(this._columnOptions.map((column) => [column.fieldName, column]));
		const selectedColumns = selectedValues
			.map((fieldName) => columnsByField.get(fieldName))
			.filter((column) => column)
			.map((column) => ({ ...column, visible: true }));
		const hiddenColumns = this._columnOptions
			.filter((column) => !selectedValues.includes(column.fieldName))
			.map((column) => ({ ...column, visible: false }));
		return [...selectedColumns, ...hiddenColumns];
	}
	getSortColumn(fieldName) {
		const availableColumns = this._columnOptions.length ? this._columnOptions : this.columns;
		const directColumn = availableColumns.find((item) => item.fieldName === fieldName);
		if (directColumn) return directColumn;
		const renderedColumn = this.columns.find((item) => item.fieldName === fieldName);
		if (renderedColumn?.sortFieldName) {
			return availableColumns.find((item) => item.fieldName === renderedColumn.sortFieldName);
		}
		if (fieldName === 'recordUrl') {
			return availableColumns.find((item) => this.getFieldKey(item.fieldName) === 'name');
		}
		if (fieldName?.endsWith('Url')) {
			const sourceFieldName = fieldName.slice(0, -3);
			return availableColumns.find((item) => item.fieldName === sourceFieldName);
		}
		return null;
	}
	sortRows(rows, column, ascending) {
		return [...rows].sort((left, right) => {
			const leftValue = this.getSortValue(left[column.fieldName], column);
			const rightValue = this.getSortValue(right[column.fieldName], column);
			const leftEmpty = leftValue === null;
			const rightEmpty = rightValue === null;
			if (leftEmpty || rightEmpty) {
				if (leftEmpty && rightEmpty) return 0;
				return leftEmpty ? (ascending ? -1 : 1) : ascending ? 1 : -1;
			}
			if (leftValue === rightValue) return 0;
			const comparison = this.compareSortValues(leftValue, rightValue, column.dataType);
			return ascending ? comparison : -comparison;
		});
	}
	getSortValue(value, column) {
		if (value == null || (typeof value === 'string' && value.trim() === '')) return null;
		if (column.dataType === 'boolean') return value === true || value === 'true';
		if (this.isNumericType(column.dataType)) return Number(value);
		if (column.dataType === 'date' || column.dataType === 'datetime') return this.parseSortDate(value);
		return this.normalizeSortText(value);
	}
	compareSortValues(leftValue, rightValue, dataType) {
		if (dataType === 'boolean') return Number(leftValue) - Number(rightValue);
		if (this.isNumericType(dataType) || dataType === 'date' || dataType === 'datetime') return leftValue - rightValue;
		return leftValue.localeCompare(rightValue, undefined, { sensitivity: 'base', numeric: true });
	}
	isNumericType(dataType) {
		return ['currency', 'double', 'int', 'percent', 'number'].includes(dataType);
	}
	parseSortDate(value) {
		const timestamp = Date.parse(value);
		return Number.isNaN(timestamp) ? 0 : timestamp;
	}
	normalizeSortText(value) {
		return String(value)
			.normalize('NFD')
			.replace(/\p{Diacritic}/gu, '')
			.trim()
			.toLowerCase();
	}
	getFieldKey(value) {
		return (value || '').trim().split('.').pop().toLowerCase();
	}
	getSearchValue(row, column) {
		return row[column.sortFieldName || column.fieldName];
	}
	getRowText(value) {
		if (value && typeof value === 'object') return String(value.label ?? value.value ?? '');
		try {
			const parsedValue = JSON.parse(value);
			return String(parsedValue.label ?? parsedValue.value ?? '');
		} catch {
			return String(value ?? '');
		}
	}
	autoFitColumns(data) {
		return data[0].map((_, index) => ({ wch: Math.max(...data.map((row) => String(row[index] ?? '').length)) + 2 }));
	}
	reduceError(error) {
		return error?.body?.message || error?.message || JSON.stringify(error);
	}
	showToast(title, message, variant) {
		this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
	}
}