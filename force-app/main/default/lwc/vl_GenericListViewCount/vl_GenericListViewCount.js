import { LightningElement, api, wire } from 'lwc';
import { getListUi } from 'lightning/uiListApi';

const PAGE_SIZE = 200;
const MAX_PAGE_TOKEN = 2000;
const countCache = new Map();

export default class VlGenericListViewCount extends LightningElement {
	_objectApiName;
	_listViewApiName;
	@api isSelected = false;
	pageToken;
	lastProcessedPageToken;
	hasProcessedPage = false;
	loadedRecordCount = 0;
	count = '-';

	get cacheKey() {
		return `${this._objectApiName || ''}|${this._listViewApiName || ''}`;
	}

	get countClass() {
		return `count${this.isSelected ? ' selected' : ''}`;
	}

	@api
	get objectApiName() {
		return this._objectApiName;
	}

	set objectApiName(value) {
		if (value !== this._objectApiName) {
			this._objectApiName = value;
			this.reset();
		}
	}

	@api
	get listViewApiName() {
		return this._listViewApiName;
	}

	set listViewApiName(value) {
		if (value !== this._listViewApiName) {
			this._listViewApiName = value;
			this.reset();
		}
	}

	@wire(getListUi, {
		objectApiName: '$objectApiName',
		listViewApiName: '$listViewApiName',
		pageSize: PAGE_SIZE,
		pageToken: '$pageToken'
	})
	wiredListView({ error, data }) {
		if (countCache.has(this.cacheKey)) {
			this.count = countCache.get(this.cacheKey);
			return;
		}
		if (data?.records) {
			if (this.hasProcessedPage && this.lastProcessedPageToken === this.pageToken) return;
			this.hasProcessedPage = true;
			this.lastProcessedPageToken = this.pageToken;
			this.loadedRecordCount += data.records.records?.length ?? 0;
			const nextPageToken = data.records.nextPageToken;
			this.count = nextPageToken ? `${this.loadedRecordCount}+` : this.loadedRecordCount;
			if (nextPageToken && this.canRequestPage(nextPageToken)) {
				this.pageToken = nextPageToken;
			} else {
				countCache.set(this.cacheKey, this.count);
			}
		} else if (error) {
			this.count = '-';
		}
	}

	canRequestPage(pageToken) {
		const numericPageToken = Number(pageToken);
		return !Number.isFinite(numericPageToken) || numericPageToken <= MAX_PAGE_TOKEN;
	}

	@api
	reset() {
		this.pageToken = undefined;
		this.lastProcessedPageToken = undefined;
		this.hasProcessedPage = false;
		this.loadedRecordCount = 0;
		this.count = '-';
	}
}