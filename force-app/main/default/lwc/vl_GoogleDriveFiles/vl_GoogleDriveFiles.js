import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMaxFileSizeMb from '@salesforce/apex/VL_GoogleDriveFilesController.getMaxFileSizeMb';
import getRootFolder from '@salesforce/apex/VL_GoogleDriveFilesController.getRootFolder';
import ensureRecordFolder from '@salesforce/apex/VL_GoogleDriveFilesController.ensureRecordFolder';
import listFolder from '@salesforce/apex/VL_GoogleDriveFilesController.listFolder';
import getExternalFileStatuses from '@salesforce/apex/VL_GoogleDriveFilesController.getExternalFileStatuses';
import GOOGLE_DRIVE_ICON from '@salesforce/resourceUrl/VL_GoogleDriveIcon';
import LABEL_TITLE from '@salesforce/label/c.VL_GoogleDriveFilesTitle';
import LABEL_ERROR from '@salesforce/label/c.VL_GoogleDriveFilesError';
import LABEL_REFRESH from '@salesforce/label/c.VL_GoogleDriveFilesRefresh';
import LABEL_EMPTY_FOLDER from '@salesforce/label/c.VL_GoogleDriveFilesEmptyFolder';
import LABEL_NO_FOLDER from '@salesforce/label/c.VL_GoogleDriveFilesNoFolder';
import LABEL_FOLDER_META from '@salesforce/label/c.VL_GoogleDriveFilesFolderMeta';
import LABEL_UPLOAD from '@salesforce/label/c.VL_GoogleDriveFilesUpload';
import LABEL_UPLOAD_SUCCESS from '@salesforce/label/c.VL_GoogleDriveFilesUploadSuccess';
import LABEL_UPLOAD_LIMIT from '@salesforce/label/c.VL_GoogleDriveFilesUploadLimit';
import LABEL_CREATE_FOLDER from '@salesforce/label/c.VL_GoogleDriveFilesCreateFolder';
import LABEL_CREATE_FOLDER_SUCCESS from '@salesforce/label/c.VL_GoogleDriveFilesCreateFolderSuccess';
import LABEL_CREATE_FOLDER_ERROR from '@salesforce/label/c.VL_GoogleDriveFilesCreateFolderError';
import LABEL_SYNCING from '@salesforce/label/c.VL_GoogleDriveFilesSyncing';
import LABEL_SYNC_ERROR from '@salesforce/label/c.VL_GoogleDriveFilesSyncError';

const FOLDER_MIME = 'application/vnd.google-apps.folder';
const BYTES_PER_MB = 1000000;
const MAX_SERVER_UPLOAD_MB = 25;
const SYNC_POLL_INTERVAL_MS = 3000;
const SYNC_STATUS_PENDING = 'Pending';
const SYNC_STATUS_ERROR = 'Error';
const SYNC_STATUS_MANUAL_REVIEW = 'Manual Review';
const SYNC_STATUS_COMPLETED = 'Completed';

export default class VlGoogleDriveFiles extends NavigationMixin(LightningElement) {
	@api recordId;
	googleDriveIconUrl = GOOGLE_DRIVE_ICON;

	label = {
		title: LABEL_TITLE,
		error: LABEL_ERROR,
		refresh: LABEL_REFRESH,
		emptyFolder: LABEL_EMPTY_FOLDER,
		noFolder: LABEL_NO_FOLDER,
		folderMeta: LABEL_FOLDER_META,
		upload: LABEL_UPLOAD,
		uploadSuccess: LABEL_UPLOAD_SUCCESS,
		uploadLimit: LABEL_UPLOAD_LIMIT,
		createFolder: LABEL_CREATE_FOLDER,
		createFolderSuccess: LABEL_CREATE_FOLDER_SUCCESS,
		createFolderError: LABEL_CREATE_FOLDER_ERROR,
		syncing: LABEL_SYNCING,
		syncError: LABEL_SYNC_ERROR
	};

	@track items = [];
	@track breadcrumbs = [];
	isLoading = true;
	isBackgroundLoading = false;
	allowMultiple = false;
	maxFileSizeMb;
	isCreatingFolder = false;
	error;
	folderResolved = false;
	statusPollingTimer;

	connectedCallback() {
		this.initialize();
	}

	disconnectedCallback() {
		this.stopStatusPolling();
	}

	async initialize() {
		this.stopStatusPolling();
		this.isLoading = true;
		this.error = undefined;
		this.folderResolved = false;
		try {
			const [maxFileSizeResult, rootResult] = await Promise.allSettled([getMaxFileSizeMb(), getRootFolder({ recordId: this.recordId })]);
			this.maxFileSizeMb = maxFileSizeResult.status === 'fulfilled' ? maxFileSizeResult.value : undefined;
			if (rootResult.status === 'rejected') {
				throw rootResult.reason;
			}
			const root = rootResult.value;
			if (!root || !root.folderId) {
				this.breadcrumbs = [];
				this.items = [];
				this.folderResolved = false;
				this.isLoading = false;
				return;
			}
			this.folderResolved = true;
			this.breadcrumbs = [{ id: root.folderId, name: root.folderName || this.label.title, isReadOnly: false }];
			await this.loadCurrentFolder();
		} catch (err) {
			this.handleError(err);
		}
	}

	handleUploadFinished(event) {
		const uploadedFiles = event.detail?.files || [];
		if (!uploadedFiles.length) {
			return;
		}

		this.showToast(this.label.upload, this.label.uploadSuccess, 'success');
		if (this.folderResolved) {
			this.loadCurrentFolder();
		}
	}

	async loadCurrentFolder() {
		this.isLoading = true;
		try {
			const data = await listFolder({ folderId: this.currentFolderId, recordId: this.recordId });
			this.items = this.sortItems((data || []).map((item) => this.decorate(item)));
			this.error = undefined;
		} catch (err) {
			this.handleError(err);
		} finally {
			this.isLoading = false;
			this.updateStatusPolling();
		}
	}

	get hasPendingItems() {
		return this.items.some((item) => item.syncStatus === SYNC_STATUS_PENDING);
	}

	updateStatusPolling() {
		if (this.hasPendingItems && this.folderResolved) {
			this.startStatusPolling();
		} else {
			this.stopStatusPolling();
		}
	}

	startStatusPolling() {
		if (this.statusPollingTimer || !this.hasPendingItems || !this.folderResolved) {
			return;
		}
		// eslint-disable-next-line @lwc/lwc/no-async-operation
		this.statusPollingTimer = setInterval(() => {
			if (!this.isLoading && !this.isBackgroundLoading) {
				this.refreshPendingFilesInBackground();
			}
		}, SYNC_POLL_INTERVAL_MS);
	}

	stopStatusPolling() {
		if (this.statusPollingTimer) {
			clearInterval(this.statusPollingTimer);
			this.statusPollingTimer = undefined;
		}
	}

	async refreshPendingFilesInBackground() {
		if (this.isBackgroundLoading || this.isLoading || !this.folderResolved) {
			return;
		}
		const pendingItems = this.items.filter((item) => item.syncStatus === SYNC_STATUS_PENDING && item.externalFileId);
		if (!pendingItems.length) {
			this.updateStatusPolling();
			return;
		}

		const folderId = this.currentFolderId;
		this.isBackgroundLoading = true;
		try {
			const statuses = await getExternalFileStatuses({
				recordId: this.recordId,
				externalFileIds: pendingItems.map((item) => item.externalFileId)
			});
			if (folderId !== this.currentFolderId || !this.folderResolved) {
				return;
			}

			const completedStatuses = (statuses || []).filter((status) => status.status === SYNC_STATUS_COMPLETED && status.remoteFileId);
			const driveItemsById = new Map();
			if (completedStatuses.length) {
				try {
					const driveItems = await listFolder({ folderId, recordId: this.recordId });
					if (folderId !== this.currentFolderId || !this.folderResolved) {
						return;
					}
					for (const driveItem of driveItems || []) {
						if (driveItem.id) {
							driveItemsById.set(driveItem.id, driveItem);
						}
					}
				} catch (err) {
					this.backgroundRefreshError = err;
				}
			}

			const statusByExternalFileId = new Map((statuses || []).map((status) => [status.externalFileId, status]));
			let hasChanges = false;
			const updatedItems = this.items.map((item) => {
				const status = statusByExternalFileId.get(item.externalFileId);
				if (!status || !this.hasSyncStatusChanged(item, status)) {
					return item;
				}

				hasChanges = true;
				const completedDriveItem = driveItemsById.get(status.remoteFileId);
				if (status.status === SYNC_STATUS_COMPLETED && completedDriveItem) {
					return this.decorate(completedDriveItem);
				}
				return this.decorate({
					...item,
					syncStatus: status.status,
					syncError: status.error,
					webViewLink: status.remoteLinkUrl || item.webViewLink
				});
			});

			if (hasChanges) {
				this.items = this.sortItems(updatedItems);
			}
			this.backgroundRefreshError = undefined;
		} catch (err) {
			this.backgroundRefreshError = err;
		} finally {
			this.isBackgroundLoading = false;
			this.updateStatusPolling();
		}
	}

	hasSyncStatusChanged(item, status) {
		return (
			item.syncStatus !== status.status ||
			item.syncError !== status.error ||
			(status.status === SYNC_STATUS_COMPLETED && item.webViewLink !== (status.remoteLinkUrl || item.webViewLink))
		);
	}

	get currentFolderId() {
		return this.breadcrumbs.length ? this.breadcrumbs[this.breadcrumbs.length - 1].id : null;
	}

	get hasItems() {
		return this.items && this.items.length > 0;
	}

	get hasError() {
		return !!this.error;
	}

	get isEmptyFolder() {
		return this.folderResolved && !this.hasItems;
	}

	get showNoFolder() {
		return !this.folderResolved && !this.hasError;
	}

	get showUploadControl() {
		const currentBreadcrumb = this.breadcrumbs[this.breadcrumbs.length - 1];
		return this.folderResolved && !this.isLoading && !currentBreadcrumb?.isReadOnly;
	}

	get effectiveMaxFileSizeMb() {
		const configuredMaxMb = Number(this.maxFileSizeMb);
		if (!Number.isFinite(configuredMaxMb) || configuredMaxMb <= 0) {
			return 0;
		}
		return Math.min(configuredMaxMb, MAX_SERVER_UPLOAD_MB);
	}

	get hasUploadLimit() {
		return this.effectiveMaxFileSizeMb > 0;
	}

	get uploadLimitLabel() {
		return this.label.uploadLimit.replace('{0}', String(this.effectiveMaxFileSizeMb));
	}

	handleTileClick(event) {
		const { id, folder, link, name, readOnly } = event.currentTarget.dataset;
		if (folder === 'true') {
			const currentBreadcrumb = this.breadcrumbs[this.breadcrumbs.length - 1];
			this.breadcrumbs = [...this.breadcrumbs, { id, name, isReadOnly: currentBreadcrumb?.isReadOnly === true || readOnly === 'true' }];
			this.loadCurrentFolder();
			return;
		}
		if (link) {
			this[NavigationMixin.Navigate]({
				type: 'standard__webPage',
				attributes: { url: link }
			});
		}
	}

	handleBreadcrumbClick(event) {
		const index = Number(event.currentTarget.dataset.index);
		if (index === this.breadcrumbs.length - 1) {
			return;
		}
		this.breadcrumbs = this.breadcrumbs.slice(0, index + 1);
		this.loadCurrentFolder();
	}

	handleRefresh() {
		if (this.folderResolved) {
			this.loadCurrentFolder();
		} else {
			this.initialize();
		}
	}

	async handleCreateFolder() {
		if (this.isCreatingFolder || !this.recordId) {
			return;
		}
		this.isCreatingFolder = true;
		try {
			const folder = await ensureRecordFolder({ recordId: this.recordId });
			if (!folder || !folder.folderId) {
				throw new Error(this.label.createFolderError);
			}
			this.breadcrumbs = [{ id: folder.folderId, name: folder.folderName || this.label.title, isReadOnly: false }];
			this.folderResolved = true;
			await this.loadCurrentFolder();
			this.showToast(this.label.createFolder, this.label.createFolderSuccess, 'success');
		} catch {
			this.showToast(this.label.createFolder, this.label.createFolderError, 'error');
		} finally {
			this.isCreatingFolder = false;
		}
	}

	decorate(item) {
		const currentBreadcrumb = this.breadcrumbs[this.breadcrumbs.length - 1];
		const syncStatus = item.syncStatus;
		const isPending = syncStatus === SYNC_STATUS_PENDING;
		const isError = syncStatus === SYNC_STATUS_ERROR;
		const isManualReview = syncStatus === SYNC_STATUS_MANUAL_REVIEW;
		return {
			id: item.id,
			name: item.name,
			isFolder: item.isFolder,
			isLinkedFolder: item.isLinkedFolder,
			isReadOnly: currentBreadcrumb?.isReadOnly === true || item.isReadOnly === true,
			webViewLink: item.webViewLink,
			modifiedTime: item.modifiedTime,
			externalFileId: item.externalFileId,
			iconName: this.resolveIcon(item),
			metaLabel: item.isFolder ? this.label.folderMeta : this.formatSize(item.sizeBytes),
			syncStatus,
			isUnprocessed: isPending || isError || isManualReview,
			syncIconName: isError ? 'utility:error' : isPending ? 'utility:sync' : isManualReview ? 'utility:warning' : undefined,
			syncVariant: isError ? 'error' : isPending || isManualReview ? 'warning' : undefined,
			syncStatusClass: `tile-status tile-status-${(syncStatus || '').replace(/\s+/g, '-')}`,
			syncTooltip: isError || isManualReview ? item.syncError || this.label.syncError : isPending ? this.label.syncing : undefined
		};
	}

	sortItems(items) {
		return [...items].sort((leftItem, rightItem) => {
			if (leftItem.isFolder !== rightItem.isFolder) {
				return leftItem.isFolder ? -1 : 1;
			}
			const nameComparison = (leftItem.name || '').localeCompare(rightItem.name || '', undefined, {
				sensitivity: 'base',
				numeric: true
			});
			return nameComparison || (leftItem.id || '').localeCompare(rightItem.id || '');
		});
	}

	formatSize(sizeBytes) {
		if (!sizeBytes || sizeBytes <= 0) {
			return '0 MB';
		}
		return `${(sizeBytes / BYTES_PER_MB).toFixed(2)} MB`;
	}

	resolveIcon(item) {
		if (item.isFolder || item.mimeType === FOLDER_MIME) {
			return 'doctype:folder';
		}
		const mime = (item.mimeType || '').toLowerCase();
		const name = (item.name || '').toLowerCase();
		if (mime.startsWith('image/') || mime.includes('jpeg') || mime.includes('jpg') || mime.includes('png')) {
			return 'doctype:image';
		}
		if (mime.startsWith('video/')) {
			return 'doctype:video';
		}
		if (mime.startsWith('audio/')) {
			return 'doctype:audio';
		}
		if (mime.includes('pdf') || name.endsWith('.pdf')) {
			return 'doctype:pdf';
		}
		if (mime.includes('word') || mime.includes('document') || name.endsWith('.doc') || name.endsWith('.docx')) {
			return 'doctype:word';
		}
		if (
			mime.includes('sheet') ||
			mime.includes('excel') ||
			mime.includes('excel_x') ||
			mime.includes('csv') ||
			name.endsWith('.xls') ||
			name.endsWith('.xlsx') ||
			name.endsWith('.csv')
		) {
			return 'doctype:excel';
		}
		if (mime.includes('presentation') || mime.includes('powerpoint') || name.endsWith('.ppt') || name.endsWith('.pptx')) {
			return 'doctype:ppt';
		}
		if (mime.includes('zip') || mime.includes('compressed') || name.endsWith('.zip') || name.endsWith('.rar')) {
			return 'doctype:zip';
		}
		if (mime.includes('text') || name.endsWith('.txt')) {
			return 'doctype:txt';
		}
		return 'doctype:unknown';
	}

	handleError(err) {
		this.error = err;
		this.items = [];
		this.isLoading = false;
	}

	showToast(title, message, variant) {
		this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
	}
}