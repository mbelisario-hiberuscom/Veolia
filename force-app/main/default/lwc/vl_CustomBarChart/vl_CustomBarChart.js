import { LightningElement, api } from 'lwc';
import getData from '@salesforce/apex/VL_CustomDonutChartController.getData';
import { loadScript } from 'lightning/platformResourceLoader';
import chartJs from '@salesforce/resourceUrl/VL_Chartjs_4_5_1';
import currentLanguage from '@salesforce/i18n/lang';

import NODATA_LABEL from '@salesforce/label/c.VL_NoData';
// import EXPAND_TITLE_LABEL from '@salesforce/label/c.CX_TittleChartExpand';
// import HIDE_VALUES from '@salesforce/label/c.CX_TitleDonutHideValues';
// import SHOW_VALUES from '@salesforce/label/c.CX_TitleDonutShowValues';
// import PURCHASES_LABEL from '@salesforce/label/c.CX_Purchases';
// import SERVICES_LABEL from '@salesforce/label/c.CX_Services';

const COLORS = [
	'#00C979',
	'#1769E8',
	'#F5363D',
	'#F0E442',
	'#D55E00',
	'#CC79A7',
	'#56B4E9',
	'#E69F00',
	'#332288',
	'#117733',
	'#AA4499',
	'#44AA99',
	'#882255',
	'#88CCEE',
	'#CC6677',
	'#4477AA',
	'#228833',
	'#EE6677',
	'#BBBB44',
	'#66CCEE',
	'#AA3377',
	'#999933',
	'#661100',
	'#B5121B'
];

const LINE_COLOR = '#4B5563';
const CHART_FONT_FAMILY = 'Roboto, Arial, sans-serif';
const PURCHASES_DATASET_COLOR = '#00C979';
const SERVICES_DATASET_COLOR = '#1769E8';

export default class VlCustomBarChart extends LightningElement {
	@api title;
	@api controllerClass;
	@api legendPosition = 'bottom';
	@api legendTitle;
	@api legendMaxTextWidth = 150;
	@api orientation = 'vertical';
	_showValuesButton;
	_showExpandButton;
	_recordId;
	_filter;

	@api
	set showValuesButton(value) {
		this._showValuesButton = value;
	}

	get showValuesButton() {
		return this._showValuesButton !== false && this._showValuesButton !== 'false';
	}

	@api
	set showExpandButton(value) {
		this._showExpandButton = value;
	}

	get showExpandButton() {
		return this._showExpandButton !== false && this._showExpandButton !== 'false';
	}

	get normalizedLegendPosition() {
		const position = String(this.legendPosition || 'bottom').toLowerCase();
		return ['top', 'right', 'bottom'].includes(position) ? position : 'bottom';
	}

	get chartBodyClass() {
		return `chart-body chart-body--${this.normalizedLegendPosition}`;
	}

	get legendContainerClass() {
		return `legend-container legend-container--${this.normalizedLegendPosition}`;
	}

	get modalBodyClass() {
		return `modal-body modal-body--${this.normalizedLegendPosition}`;
	}

	get containerClass() {
		return this.isEmpty ? 'container container--empty' : 'container';
	}

	get normalizedOrientation() {
		const orientation = String(this.orientation || 'vertical').toLowerCase();
		return orientation === 'horizontal' ? 'horizontal' : 'vertical';
	}

	get indexAxis() {
		return this.normalizedOrientation === 'horizontal' ? 'y' : 'x';
	}

	@api
	set recordId(value) {
		this._recordId = value;
		if (this.chartJsInitialized && !this._filter) this.loadData();
	}

	get recordId() {
		return this._recordId;
	}

	chart;
	modalChart = null;
	isModalOpen = false;
	modalChartPending = false;
	chartJsInitialized = false;
	isLoading = true;
	isEmpty = true;
	labelsVisible = false;
	colors = COLORS;
	nodata = NODATA_LABEL;
	expandTitleLabel = 'EXPAND'; // EXPAND_TITLE_LABEL;
	hideValuesLabel = 'HIDE VALUES'; // HIDE_VALUES;
	showValuesLabel = 'SHOW VALUES'; // SHOW_VALUES;

	chartData = [];
	legendItems = [];

	@api
	set filter(value) {
		this._filter = value;
		if (this.chartJsInitialized) this.loadData();
	}

	get filter() {
		return this._filter;
	}

	translateLabel(label) {
		if (!label) return label;
		const trimmed = String(label).trim();
		// "MMM YYYY" format e.g. "Jan 2025"
		const matchWithYear = trimmed.match(/^(\w+)\s+(\d{4})$/);
		let value;
		if (matchWithYear) {
			const monthNum = this.getMonthNumberFromText(matchWithYear[1]);
			if (!monthNum) return label;
			const date = new Date(Date.UTC(Number(matchWithYear[2]), monthNum - 1, 1));
			const monthName = new Intl.DateTimeFormat(currentLanguage, { month: 'long', timeZone: 'UTC' }).format(date);
			return `${monthName.charAt(0).toUpperCase()}${monthName.slice(1)}`.substring(0, 3) + '.' + `${matchWithYear[2]}`.substring(2, 4);
		}

		// "MMM" format only e.g. "Jan" (no year)
		const monthNum = this.getMonthNumberFromText(trimmed);
		if (!monthNum) return label;
		const date = new Date(Date.UTC(2000, monthNum - 1, 1));
		const monthName = new Intl.DateTimeFormat(currentLanguage, { month: 'long', timeZone: 'UTC' }).format(date);
		value = `${monthName.charAt(0).toUpperCase()}${monthName.slice(1)}`;

		return value.substring(0, 3) + '.';
	}

	normalizeText(value) {
		return String(value || '')
			.normalize('NFD')
			.replace(/[\u0300-\u036f]/g, '')
			.replace(/\./g, '')
			.trim()
			.toUpperCase();
	}

	getMonthNumberFromText(monthText) {
		const normalizedInput = this.normalizeText(monthText);
		// Check in user language first, then fall back to English (Apex getMonthName returns English abbrev)
		const localesToTry = currentLanguage === 'en' || currentLanguage.startsWith('en-') ? [currentLanguage] : [currentLanguage, 'en'];
		for (const locale of localesToTry) {
			for (let month = 0; month < 12; month += 1) {
				const date = new Date(Date.UTC(2000, month, 1));
				const longName = new Intl.DateTimeFormat(locale, { month: 'long', timeZone: 'UTC' }).format(date);
				const shortName = new Intl.DateTimeFormat(locale, { month: 'short', timeZone: 'UTC' }).format(date);

				if (this.normalizeText(longName) === normalizedInput || this.normalizeText(shortName) === normalizedInput) {
					return month + 1;
				}
			}
		}

		return null;
	}

	renderedCallback() {
		if (this.modalChartPending) {
			this.modalChartPending = false;
			this.renderModalChart();
		}
		if (this.chartJsInitialized) return;

		this.chartJsInitialized = true;

		loadScript(this, chartJs)
			.then(() => {
				this.loadData();
			})
			.catch((error) => {
				console.error('Error loading ChartJS', error);
			});
	}

	loadData() {
		this.isLoading = true;
		this.chartData = [];
		const filterAux = this._filter || this._recordId || 'LAST_N_MONTHS:12';
		getData({ controllerClass: this.controllerClass, filter: filterAux })
			.then((data) => {
				this.chartData = this.normalizeChartData(data);
				if (this.chartData.labels.length > 0) {
					this.isEmpty = false;
				} else {
					this.isEmpty = true;
				}

				this.renderChart(this.chartData);
			})
			.catch((error) => {
				this.isLoading = false;
				console.error(error);
			});
	}

	normalizeChartData(data) {
		const payload = Array.isArray(data) && data.length ? data[0] : {};
		const rawLabels = Array.isArray(payload.labels) ? payload.labels : [];
		const rawDatasets = Array.isArray(payload.datasets) ? payload.datasets : [];
		const labelColors = rawLabels.map((l) => (l && typeof l === 'object' ? l.color : null));
		const hasLabelColors = labelColors.some((color) => !!color);

		const labels = rawLabels.map((l) => {
			const raw = l && typeof l === 'object' ? l.text : l;
			return this.translateLabel(raw);
		});

		const mappedDatasets = rawDatasets.map((ds) => ({
			type: ds.chartType || 'bar',
			label: ds.chartTitle || '',
			data: (Array.isArray(ds.values) ? ds.values : []).map((item) => this.toNumber(item)),
			hoverOffset: 10,
			hoverBorderWidth: 1,
			hoverBorderColor: '#222',
			fixedColor: ds.color || null,
			datasetOrder: ds.order != null ? ds.order : null
		}));

		const barDatasetsCount = mappedDatasets.filter((ds) => ds.type === 'bar').length;
		const usePerValueColors = hasLabelColors && barDatasetsCount === 1;

		const allNumericLabels = mappedDatasets.length > 0 && mappedDatasets.every((ds) => ds.label !== '' && !isNaN(Number(ds.label)));
		const hasExplicitOrder = mappedDatasets.some((ds) => ds.datasetOrder != null);

		let datasets;
		if (payload.showDiff) {
			datasets = mappedDatasets.map((ds, index) => ({
				...ds,
				backgroundColor: this.getDatasetBackgroundColor(ds, index, labelColors, usePerValueColors),
				borderColor: LINE_COLOR,
				borderWidth: 1
			}));
		} else {
			datasets = mappedDatasets
				.sort((a, b) => {
					if (hasExplicitOrder) {
						if (a.datasetOrder == null && b.datasetOrder == null) return 0;
						if (a.datasetOrder == null) return 1;
						if (b.datasetOrder == null) return -1;
						return a.datasetOrder - b.datasetOrder;
					}
					return allNumericLabels ? Number(b.label) - Number(a.label) : a.label.localeCompare(b.label);
				})
				.map((ds, index) => ({
					...ds,
					backgroundColor: this.getDatasetBackgroundColor(ds, index, labelColors, usePerValueColors),
					borderColor: ds.type !== 'line' ? LINE_COLOR : this.getDatasetBackgroundColor(ds, index, labelColors, usePerValueColors),
					borderWidth: 1
				}));
		}

		const lineProps = this.getLineDatasetProps();
		datasets.forEach((ds, i) => {
			if (ds.type !== 'line') return;
			const colorProps = datasets.length === 1 ? { borderColor: LINE_COLOR, backgroundColor: LINE_COLOR } : {};
			datasets[i] = { ...ds, ...colorProps, ...lineProps };
		});

		if (payload.showDiff && datasets.length >= 2) {
			const diff = datasets[0].data.map((value, index) => value + (datasets[1].data[index] || 0));
			datasets.unshift({
				type: 'line',
				label: payload.diffTitle || 'Diferencia',
				data: diff,
				borderColor: LINE_COLOR,
				backgroundColor: LINE_COLOR,
				...this.getLineDatasetProps()
			});
		}

		return { labels, datasets, showStacked: !!payload.showStacked, hasLabelColors, usePerValueColors };
	}

	get hasLegendItems() {
		return Array.isArray(this.legendItems) && this.legendItems.length > 0;
	}

	buildLegendItems(chartData) {
		const { datasets, labels, usePerValueColors } = chartData;
		const valueFormatter = new Intl.NumberFormat(currentLanguage, { maximumFractionDigits: 2 });
		const percentageFormatter = new Intl.NumberFormat(currentLanguage, { maximumFractionDigits: 1 });
		const labelStyle = `max-width: ${Number(this.legendMaxTextWidth) || 170}px`;
		const formatStats = (value, total) => ({
			value: valueFormatter.format(value),
			percentage: `${percentageFormatter.format(total > 0 ? (value / total) * 100 : 0)}%`
		});

		if (usePerValueColors && labels.length > 0) {
			const firstBarDataset = datasets.find((ds) => ds.type === 'bar');
			const barColors = Array.isArray(firstBarDataset?.backgroundColor) ? firstBarDataset.backgroundColor : [];
			const values = Array.isArray(firstBarDataset?.data) ? firstBarDataset.data.map((value) => Number(value) || 0) : [];
			const total = values.reduce((sum, value, index) => {
				const isVisible = !this.chart || this.chart.getDataVisibility(index);
				return sum + (isVisible ? value : 0);
			}, 0);
			this.legendItems = labels.map((label, i) => ({
				label,
				labelStyle,
				...(this.chart && !this.chart.getDataVisibility(i) ? { value: '', percentage: '' } : formatStats(values[i] || 0, total)),
				index: i,
				hidden: this.chart ? !this.chart.getDataVisibility(i) : false,
				legendType: 'value',
				colorStyle: `background-color: ${barColors[i] || this.colors[i % this.colors.length]}`,
				labelClass: this.chart && !this.chart.getDataVisibility(i) ? 'legend-label legend-label--hidden' : 'legend-label'
			}));
			return;
		}

		const datasetValues = datasets.map((dataset, index) => {
			if (this.chart && !this.chart.isDatasetVisible(index)) return 0;
			return dataset.data.reduce((sum, value) => sum + (Number(value) || 0), 0);
		});
		const total = datasetValues.reduce((sum, value) => sum + value, 0);
		this.legendItems = datasets.map((ds, i) => ({
			label: ds.label,
			labelStyle,
			...(this.chart && !this.chart.isDatasetVisible(i) ? { value: '', percentage: '' } : formatStats(datasetValues[i], total)),
			index: i,
			hidden: this.chart ? !this.chart.isDatasetVisible(i) : false,
			legendType: 'dataset',
			colorStyle: `background-color: ${this.getLegendColor(ds, i)}`,
			labelClass: this.chart && !this.chart.isDatasetVisible(i) ? 'legend-label legend-label--hidden' : 'legend-label'
		}));
	}

	getDatasetBackgroundColor(dataset, index, labelColors, usePerValueColors) {
		const baseColor = this.colors[index % this.colors.length];
		if (dataset.fixedColor) {
			return dataset.fixedColor;
		}
		const fixedDatasetColor = this.getFixedDatasetColor(dataset?.label);
		if (fixedDatasetColor) {
			return fixedDatasetColor;
		}
		if (usePerValueColors && dataset.type === 'bar' && Array.isArray(dataset.data) && labelColors.length === dataset.data.length) {
			return labelColors.map((color) => color || baseColor);
		}
		return baseColor;
	}

	getLegendColor(dataset, index) {
		if (Array.isArray(dataset.backgroundColor)) {
			const firstColor = dataset.backgroundColor.find((color) => !!color);
			return firstColor || this.colors[index % this.colors.length];
		}
		if (dataset.backgroundColor) {
			return dataset.backgroundColor;
		}
		return this.colors[index % this.colors.length];
	}

	getFixedDatasetColor(datasetLabel) {
		const normalizedLabel = String(datasetLabel || '')
			.trim()
			.toLowerCase();
		if (normalizedLabel === 'purchases') {
			return PURCHASES_DATASET_COLOR;
		}
		if (normalizedLabel === 'services') {
			return SERVICES_DATASET_COLOR;
		}
		return null;
	}

	handleLegendClick(event) {
		const index = Number(event.currentTarget.dataset.index);
		if (!this.chart) return;
		const legendItem = this.legendItems[index];
		if (!legendItem) return;

		if (legendItem.legendType === 'value') {
			this.chart.toggleDataVisibility(index);
			this.chart.update();
			if (this.modalChart) {
				this.modalChart.toggleDataVisibility(index);
				this.modalChart.update();
			}
			this.buildLegendItems(this.chartData);
			return;
		}

		const dataset = this.chart.data.datasets[index];
		if (!dataset) return;
		dataset.hidden = !dataset.hidden;
		this.chart.update();
		if (this.modalChart) {
			this.modalChart.setDatasetVisibility(index, !dataset.hidden);
			this.modalChart.update();
		}
		this.buildLegendItems(this.chartData);
	}

	getLineDatasetProps() {
		return {
			yAxisID: 'y',
			clip: false,
			borderWidth: 2,
			pointRadius: 3,
			tension: 0.3,
			hoverOffset: 10,
			hoverBorderWidth: 1,
			hoverBorderColor: '#222'
		};
	}

	toNumber(value) {
		if (value === null || value === undefined) return null;
		const n = Number(value);
		return isNaN(n) ? null : n;
	}

	getValueLabelsPlugin() {
		const formatter = new Intl.NumberFormat(currentLanguage, { notation: 'compact', compactDisplay: 'short' });
		return {
			id: 'barValueLabels',
			afterDatasetsDraw: (chart) => {
				if (!this.labelsVisible) return;

				const { ctx } = chart;
				chart.data.datasets.forEach((dataset, datasetIndex) => {
					if (dataset.type === 'line') return;
					const meta = chart.getDatasetMeta(datasetIndex);
					meta.data.forEach((bar, index) => {
						const value = Number(dataset.data[index]);
						if (!Number.isFinite(value) || !bar || !chart.getDataVisibility(index)) return;

						const text = formatter.format(value);
						const y = value < 0 ? bar.base + 12 : bar.y - 8;
						ctx.save();
						ctx.font = `500 11px ${CHART_FONT_FAMILY}`;
						ctx.textAlign = 'center';
						ctx.textBaseline = 'middle';
						ctx.lineJoin = 'round';
						ctx.strokeStyle = '#4B5563';
						ctx.lineWidth = 3;
						ctx.strokeText(text, bar.x, y);
						ctx.fillStyle = '#ffffff';
						ctx.fillText(text, bar.x, y);
						ctx.restore();
					});
				});
			}
		};
	}

	toggleLabels() {
		this.labelsVisible = !this.labelsVisible;
		this.chart?.update();
		this.modalChart?.update();
	}

	get labelsToggleTitle() {
		return this.labelsVisible ? this.hideValuesLabel : this.showValuesLabel;
	}

	getChartScales(showStacked) {
		const numericAxis = this.indexAxis === 'y' ? 'x' : 'y';
		const categoryAxis = numericAxis === 'x' ? 'y' : 'x';
		const numericScale = {
			grid: {
				drawOnChartArea: true,
				color: (context) => (context.tick.value === 0 ? 'rgb(0, 0, 0)' : 'rgba(0,0,0,0.08)')
			},
			border: { display: false },
			stacked: !!showStacked,
			beginAtZero: true,
			afterBuildTicks(scale) {
				scale.ticks = scale.ticks.filter((tick) => !tick._manuallyAdded);
				const hasZero = scale.ticks.some((tick) => tick.value === 0);
				if (!hasZero) {
					scale.ticks.push({ value: 0, _manuallyAdded: true });
					scale.ticks.sort((a, b) => a.value - b.value);
				}
			},
			ticks: {
				count: 5,
				callback: (value, index, ticks) => {
					const tickObj = ticks.find((tick) => tick.value === value);
					if (value === 0 && tickObj && tickObj._manuallyAdded) return '';
					const options = {
						notation: 'compact',
						compactDisplay: 'short'
					};
					const formatter = new Intl.NumberFormat(currentLanguage, options);
					return formatter.format(value);
				}
			}
		};
		const categoryScale = {
			grid: { display: false },
			border: { display: false },
			stacked: !!showStacked
		};

		return {
			[categoryAxis]: categoryScale,
			[numericAxis]: numericScale
		};
	}

	renderChart(data) {
		const canvas = this.template.querySelector('canvas');

		if (this.isEmpty) {
			canvas.classList.add('hide');
		} else {
			canvas.classList.remove('hide');
		}

		const ctx = canvas.getContext('2d');
		const chartData = data;

		if (this.chart) {
			this.chart.data.labels = chartData.labels;
			this.chart.data.datasets = chartData.datasets;
			this.chart.update();
		} else {
			this.chart = new window.Chart(ctx, {
				type: 'bar',
				data: {
					labels: chartData.labels,
					datasets: chartData.datasets
				},
				options: {
					indexAxis: this.indexAxis,
					layout: {
						padding: 20
					},
					responsive: true,
					maintainAspectRatio: false,
					plugins: {
						tooltip: {
							backgroundColor: 'rgba(55, 55, 55, 0.96)',
							titleColor: '#ffffff',
							bodyColor: '#ffffff',
							callbacks: {
								title: (tooltipItems) => (tooltipItems.length ? tooltipItems[0].label : ''),
								label: (context) => {
									if (context.chart.data.datasets.length !== 1) {
										return `${context.dataset.label}: ${context.formattedValue}`;
									}
									const chart = context.chart;
									const tooltipData = Array.isArray(context.dataset.data) ? context.dataset.data : [];
									const total = tooltipData.reduce((sum, item, i) => {
										return sum + (chart.getDataVisibility(i) ? Number(item) || 0 : 0);
									}, 0);
									const currentValue = Number(context.raw) || 0;
									const percent = total > 0 ? (currentValue / total) * 100 : 0;

									let options = {
										notation: 'compact',
										compactDisplay: 'short'
									};
									const formatter = new Intl.NumberFormat(currentLanguage, options);

									const formattedPercent = formatter.format(percent);
									const formattedTotal = formatter.format(total);

									return [`${context.label}: ${currentValue.toFixed(2)}`, `(${formattedPercent}% of ${formattedTotal})`];
								}
							},
							titleFont: {
								size: 14,
								weight: 'bold'
							},
							bodyFont: {
								size: 12
							},
							padding: 12,
							cornerRadius: 8,
							displayColors: true,
							boxPadding: 4,
							filter: (item) => item.raw != null
						},
						legend: {
							display: false
						}
					},
					interaction: {
						mode: 'nearest',
						intersect: true
					},
					scales: this.getChartScales(chartData.showStacked),
					datasets: {
						bar: {
							categoryPercentage: 0.9,
							barPercentage: 0.8
						}
					},
					onHover: (event, chartElement) => {
						event.native.target.style.cursor = chartElement[0] ? 'pointer' : 'default';
					}
				},
				plugins: [this.getValueLabelsPlugin()]
			});
		}

		this.isLoading = false;
		this.buildLegendItems(chartData);
	}

	openModal() {
		this.isModalOpen = true;
		this.modalChartPending = true;
	}

	closeModal() {
		if (this.modalChart) {
			this.modalChart.destroy();
			this.modalChart = null;
		}
		this.isModalOpen = false;
	}

	handleBackdropClick() {
		this.closeModal();
	}

	stopPropagation(event) {
		event.stopPropagation();
	}

	renderModalChart() {
		const canvas = this.template.querySelector('canvas.modal-canvas');
		if (!canvas || !this.chartData || !this.chartData.labels) return;

		if (this.modalChart) {
			this.modalChart.destroy();
			this.modalChart = null;
		}

		const ctx = canvas.getContext('2d');
		const chartData = this.chartData;

		this.modalChart = new window.Chart(ctx, {
			type: 'bar',
			data: {
				labels: chartData.labels,
				datasets: chartData.datasets.map((ds) => ({ ...ds }))
			},
			options: {
				indexAxis: this.indexAxis,
				layout: { padding: 20 },
				responsive: true,
				maintainAspectRatio: false,
				plugins: {
					tooltip: {
						backgroundColor: 'rgba(55, 55, 55, 0.96)',
						titleColor: '#ffffff',
						bodyColor: '#ffffff',
						callbacks: {
							title: (tooltipItems) => (tooltipItems.length ? tooltipItems[0].label : ''),
							label: (context) => {
								if (context.chart.data.datasets.length !== 1) {
									return `${context.dataset.label}: ${context.formattedValue}`;
								}
								const chart = context.chart;
								const data = Array.isArray(context.dataset.data) ? context.dataset.data : [];
								const total = data.reduce((sum, item, i) => {
									return sum + (chart.getDataVisibility(i) ? Number(item) || 0 : 0);
								}, 0);
								const currentValue = Number(context.raw) || 0;
								const percent = total > 0 ? (currentValue / total) * 100 : 0;
								const formatter = new Intl.NumberFormat(currentLanguage, { notation: 'compact', compactDisplay: 'short' });
								return [
									`${context.label}: ${currentValue.toFixed(2)}`,
									`(${formatter.format(percent)}% of ${formatter.format(total)})`
								];
							}
						},
						titleFont: { size: 14, weight: 'bold' },
						bodyFont: { size: 12 },
						padding: 12,
						cornerRadius: 8,
						displayColors: true,
						boxPadding: 4,
						filter: (item) => item.raw != null
					},
					legend: { display: false }
				},
				interaction: { mode: 'nearest', intersect: true },
				scales: this.getChartScales(chartData.showStacked),
				datasets: { bar: { categoryPercentage: 0.9, barPercentage: 0.8 } },
				onHover: (event, chartElement) => {
					event.native.target.style.cursor = chartElement[0] ? 'pointer' : 'default';
				}
			},
			plugins: [this.getValueLabelsPlugin()]
		});

		this.legendItems.forEach((item) => {
			if (item.hidden) {
				if (item.legendType === 'value') {
					this.modalChart.toggleDataVisibility(item.index);
				} else {
					this.modalChart.setDatasetVisibility(item.index, false);
				}
			}
		});
		this.modalChart.update();
	}
}