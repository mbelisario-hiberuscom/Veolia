import { LightningElement, api } from 'lwc';
import getData from '@salesforce/apex/VL_CustomDonutChartController.getData';
import { loadScript } from 'lightning/platformResourceLoader';
import chartJs from '@salesforce/resourceUrl/VL_Chartjs_4_5_1';

import currentLanguage from '@salesforce/i18n/lang';

import NODATA_LABEL from '@salesforce/label/c.VL_NoData';
//import EXPAND_TITLE_LABEL from '@salesforce/label/c.CX_TittleChartExpand';
//import HIDE_VALUES from '@salesforce/label/c.CX_TitleDonutHideValues';
//import SHOW_VALUES from '@salesforce/label/c.CX_TitleDonutShowValues';

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

const CHART_FONT_FAMILY = 'Roboto, Arial, sans-serif';

export default class VlCustomDonutChart extends LightningElement {
	@api title;
	@api controllerClass;
	@api legendPosition = 'bottom';
	@api legendTitle;
	@api legendMaxTextWidth = 150;
	_showValuesButton;
	_showExpandButton;

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
	_recordId;
	_filter;

	@api
	set recordId(value) {
		this._recordId = value;
		if (this.chartJsInitialized && !this._filter) this.loadData();
	}

	get recordId() {
		return this._recordId;
	}

	@api
	set filter(value) {
		this._filter = value;
		if (this.chartJsInitialized) this.loadData();
	}

	get filter() {
		return this._filter;
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

	chart;
	modalChart;
	chartJsInitialized = false;
	isLoading = true;
	isEmpty = true;
	isModalOpen = false;
	labelsVisible = false;

	colors = COLORS;
	nodata = NODATA_LABEL;
	legendItems = [];
	expandTitleLabel = 'EXPAND_TITLE_LABEL'; //EXPAND_TITLE_LABEL;
	hideValuesLabel = 'HIDE_VALUES'; //HIDE_VALUES;
	showValuesLabel = 'SHOW_VALUES'; //SHOW_VALUES;

	renderedCallback() {
		if (this.modalChartPending) {
			this.modalChartPending = false;
			this.renderModalChart();
		}
		if (this.chartJsInitialized) return;

		loadScript(this, chartJs)
			.then(() => {
				this.chartJsInitialized = true;
				this.loadData();
			})
			.catch((error) => {
				console.error('Error loading ChartJS', error);
			});
	}

	loadData() {
		this.isLoading = true;
		getData({ controllerClass: this.controllerClass, filter: this._filter || this._recordId })
			.then((data) => {
				const chartData = this.normalizeChartData(data);
				if (chartData.labels.length > 0) {
					this.isEmpty = false;
				} else {
					this.isEmpty = true;
				}
				this.renderChart(chartData);
			})
			.catch((error) => {
				this.isLoading = false;
				console.error(error);
			});
	}

	wrapLegendTextByWidth(canvasCtx, text) {
		const legendText = String(text || '');
		const maxWidth = Number(this.legendMaxTextWidth) || 170;

		if (!legendText || !canvasCtx) {
			return legendText;
		}

		canvasCtx.save();
		canvasCtx.font = `400 14px ${CHART_FONT_FAMILY}`;

		if (canvasCtx.measureText(legendText).width <= maxWidth) {
			canvasCtx.restore();
			return legendText;
		}

		const words = legendText.split(' ');
		const lines = [];
		let currentLine = '';

		for (const word of words) {
			const testLine = currentLine ? `${currentLine} ${word}` : word;
			if (canvasCtx.measureText(testLine).width > maxWidth && currentLine) {
				lines.push(currentLine);
				currentLine = word;
			} else {
				currentLine = testLine;
			}
		}

		if (currentLine) {
			lines.push(currentLine);
		}

		canvasCtx.restore();
		return lines.length > 1 ? lines : legendText;
	}

	// NOTE: wrapLegendTextByWidth kept for backwards compat but no longer used (legend is in HTML)
	normalizeChartData(data) {
		const payload = Array.isArray(data) && data.length ? data[0] : {};
		const rawLabels = Array.isArray(payload.labels) ? payload.labels : [];
		const datasets = Array.isArray(payload.datasets) ? payload.datasets : [];
		const primary = datasets[0] || {};
		const rawValues = Array.isArray(primary.values) ? primary.values : [];

		const combined = rawLabels
			.map((l, i) => ({
				label: l && typeof l === 'object' ? l.text : l,
				value: Number(rawValues[i]) || 0,
				order: l && typeof l === 'object' && l.order != null ? l.order : null,
				color: l && typeof l === 'object' && l.color ? l.color.trim() : null
			}))
			.sort((a, b) => {
				if (a.order != null && b.order != null) return a.order - b.order;
				return a.label.localeCompare(b.label);
			});

		const resolvedColors = combined.map((item, i) => item.color || COLORS[i % COLORS.length]);

		return {
			labels: combined.map((item) => item.label),
			values: combined.map((item) => item.value),
			colors: resolvedColors,
			valueChartType: primary.chartType || 'doughnut',
			showPercentInTotal: payload.showPercentInTotal === true,
			showDiff: payload.showDiff === true
		};
	}

	renderChart(chartData) {
		this._lastChartData = chartData;
		const ctx = this.template.querySelector('canvas').getContext('2d');
		const { labels, values, valueChartType, showPercentInTotal, colors, showDiff } = chartData;
		this._originalLabels = labels;
		this._showPercentInTotal = showPercentInTotal;
		this._resolvedColors = colors;
		this._showDiff = showDiff;

		const self = this;
		const centerTextPlugin = {
			id: 'centerText',
			beforeDraw(chart) {
				const { ctx: pluginCtx, chartArea } = chart;

				if (!chartArea) return;

				const x = (chartArea.left + chartArea.right) / 2;
				const y = (chartArea.top + chartArea.bottom) / 2;

				const dataset = chart.data.datasets[0];
				let total;

				if (self._showDiff) {
					total = dataset.data.reduce((result, val, i) => {
						if (!chart.getDataVisibility(i)) {
							return result;
						}

						const value = Number(val) || 0;

						if (result === null) {
							return value;
						}

						return result - value;
					}, null);
					total = total ?? 0;
				} else {
					total = dataset.data.reduce((sum, val, i) => sum + (chart.getDataVisibility(i) ? Number(val) || 0 : 0), 0);
				}

				if (dataset.data.length > 0) {
					let options = {
						notation: 'compact',
						compactDisplay: 'short'
					};

					let formatter = new Intl.NumberFormat(currentLanguage, options);
					const formattedTotal = formatter.format(total);
					const displayText = self._showPercentInTotal ? `${formattedTotal}%` : formattedTotal;

					pluginCtx.save();

					const chartWidth = chartArea.right - chartArea.left;
					const chartHeight = chartArea.bottom - chartArea.top;
					// Inner circle diameter based on cutout: '60%'
					const innerDiameter = Math.min(chartWidth, chartHeight) * 0.6;
					const maxTextWidth = innerDiameter * 0.8;

					let fontSize = Math.min(36, chartHeight / 3);
					pluginCtx.font = `bold ${fontSize}px ${CHART_FONT_FAMILY}`;

					// Shrink font until text fits inside the inner circle
					while (fontSize > 8 && pluginCtx.measureText(displayText).width > maxTextWidth) {
						fontSize -= 1;
						pluginCtx.font = `bold ${fontSize}px ${CHART_FONT_FAMILY}`;
					}

					pluginCtx.fillStyle = 'rgba(0, 0, 0, 0.8)';
					pluginCtx.textAlign = 'center';
					pluginCtx.textBaseline = 'middle';

					pluginCtx.fillText(displayText, x, y);

					pluginCtx.restore();
				}
			}
		};

		const sectorLabelsPlugin = {
			id: 'sectorLabels',
			afterDatasetsDraw(chart) {
				const { ctx: pluginCtx, chartArea } = chart;
				const dataset = chart.data.datasets[0];
				const meta = chart.getDatasetMeta(0);
				const isModalChart = chart.canvas?.classList?.contains('modal-canvas');

				if (!chartArea) return;

				const total = dataset.data.reduce((sum, val, i) => sum + (chart.getDataVisibility(i) ? Number(val) || 0 : 0), 0);
				if (!total) return;

				const numOptions = { notation: 'compact', compactDisplay: 'short' };
				const formatter = new Intl.NumberFormat(currentLanguage, numOptions);
				const SMALL_THRESHOLD = 0.08;
				const LABEL_SPACING = isModalChart ? 12 : 4;
				const PAD = isModalChart ? 8 : 4;
				const OUTSIDE_FONT_MULTIPLIER = isModalChart ? 1.28 : 1;
				const INSIDE_FONT_MULTIPLIER = isModalChart ? 1.18 : 1;
				const LABEL_OFFSET_X = isModalChart ? 56 : 32;
				const NATURAL_Y_OFFSET = isModalChart ? 32 : 20;
				const TIER_X_STEP = isModalChart ? 84 : 56;

				function getLines(value) {
					const line1 = formatter.format(value) + (self._showPercentInTotal ? '%' : '');
					const line2 = self._showPercentInTotal ? null : `${((value / total) * 100).toFixed(1)}%`;
					return { line1, line2 };
				}

				// --- Etiquetas dentro del sector (>= 8%) ---
				meta.data.forEach((arc, i) => {
					if (!self.labelsVisible) return;
					if (!chart.getDataVisibility(i)) return;

					const value = Number(dataset.data[i]) || 0;
					if (!value) return;

					const percentage = value / total;
					if (percentage < SMALL_THRESHOLD) return;

					const arcWidth = arc.outerRadius - arc.innerRadius;
					const fontSize = Math.min(isModalChart ? 18 : 13, arcWidth * 0.45 * INSIDE_FONT_MULTIPLIER);
					if (fontSize < 8) return;

					const midAngle = (arc.startAngle + arc.endAngle) / 2;
					const midRadius = (arc.innerRadius + arc.outerRadius) / 2;
					const cx = arc.x + Math.cos(midAngle) * midRadius;
					const cy = arc.y + Math.sin(midAngle) * midRadius;
					const { line1, line2 } = getLines(value);
					const lineHeight = fontSize * 1.3;
					const offsetY = line2 ? lineHeight / 2 : 0;

					pluginCtx.save();
					pluginCtx.textAlign = 'center';
					pluginCtx.textBaseline = 'middle';
					pluginCtx.lineJoin = 'round';

					// Línea 1: valor (negrita)
					pluginCtx.font = `500 ${fontSize}px ${CHART_FONT_FAMILY}`;
					pluginCtx.strokeStyle = '#4B5563';
					pluginCtx.lineWidth = 3;
					pluginCtx.strokeText(line1, cx, cy - offsetY);
					pluginCtx.fillStyle = '#ffffff';
					pluginCtx.fillText(line1, cx, cy - offsetY);

					// Línea 2: porcentaje
					if (line2) {
						const fs2 = Math.max(fontSize - 2, 7);
						pluginCtx.font = `bold ${fs2}px ${CHART_FONT_FAMILY}`;
						pluginCtx.lineWidth = fs2 * 0.2;
						pluginCtx.fillStyle = 'rgba(0, 0, 0, 0.85)';
						pluginCtx.fillText(line2, cx, cy + offsetY);
					}
					pluginCtx.restore();
				});

				// --- Recopilar etiquetas exteriores (< 8%) ---
				if (!self.labelsVisible) return;
				const outsideLabels = [];
				meta.data.forEach((arc, i) => {
					if (!chart.getDataVisibility(i)) return;

					const value = Number(dataset.data[i]) || 0;
					if (!value) return;

					const percentage = value / total;
					if (percentage >= SMALL_THRESHOLD) return;

					const arcWidth = arc.outerRadius - arc.innerRadius;
					const fontSize = Math.min(isModalChart ? 17 : 13, arcWidth * 0.45 * OUTSIDE_FONT_MULTIPLIER);
					if (fontSize < 8) return;

					const { line1, line2 } = getLines(value);
					const lineHeight = fontSize * 1.3;
					const boxHeight = line2 ? lineHeight * 2 + PAD * 2 : fontSize + PAD * 2;

					const midAngle = (arc.startAngle + arc.endAngle) / 2;
					const isRight = Math.cos(midAngle) >= 0;

					const LABEL_X_OFFSET = arc.outerRadius + LABEL_OFFSET_X;
					const rawLabelX = isRight ? arc.x + LABEL_X_OFFSET : arc.x - LABEL_X_OFFSET;
					const labelX = isRight ? Math.min(rawLabelX, chartArea.right - 2) : Math.max(rawLabelX, chartArea.left + 2);

					const naturalY = arc.y + Math.sin(midAngle) * (arc.outerRadius + NATURAL_Y_OFFSET);
					const halfH = boxHeight / 2 + 1;
					const clampedY = Math.max(halfH + 2, Math.min(chart.height - halfH - 2, naturalY));

					outsideLabels.push({
						arc,
						midAngle,
						labelX,
						naturalY: clampedY,
						adjustedY: clampedY,
						line1,
						line2,
						fontSize,
						lineHeight,
						boxHeight,
						isRight,
						color: dataset.backgroundColor[i]
					});
				});

				if (!outsideLabels.length) return;

				// --- Resolver solapamientos (pases forward + backward + clamp al canvas) ---
				function resolveOverlaps(labelItems) {
					if (labelItems.length < 2) return;

					// Siempre partir de naturalY para una resolución limpia y determinista
					labelItems.forEach((l) => {
						l.adjustedY = l.naturalY;
					});

					// Pase 1 – hacia abajo: empuja cada etiqueta por debajo de la anterior
					for (let j = 1; j < labelItems.length; j++) {
						const a = labelItems[j - 1],
							b = labelItems[j];
						const need = (a.boxHeight + b.boxHeight) / 2 + LABEL_SPACING;
						if (b.adjustedY < a.adjustedY + need) b.adjustedY = a.adjustedY + need;
					}

					// Clamp de la última al borde inferior del canvas
					const last = labelItems[labelItems.length - 1];
					const lastMaxY = chart.height - last.boxHeight / 2 - 3;
					if (last.adjustedY > lastMaxY) last.adjustedY = lastMaxY;

					// Pase 2 – hacia arriba: arrastra el resto si la última fue recortada
					for (let j = labelItems.length - 2; j >= 0; j--) {
						const a = labelItems[j],
							b = labelItems[j + 1];
						const need = (a.boxHeight + b.boxHeight) / 2 + LABEL_SPACING;
						if (a.adjustedY > b.adjustedY - need) a.adjustedY = b.adjustedY - need;
					}

					// Clamp del primero al borde superior del canvas
					const first = labelItems[0];
					const firstMinY = first.boxHeight / 2 + 3;
					if (first.adjustedY < firstMinY) first.adjustedY = firstMinY;

					// Pase 3 – hacia abajo de nuevo: garantiza separación tras el clamp superior
					for (let j = 1; j < labelItems.length; j++) {
						const a = labelItems[j - 1],
							b = labelItems[j];
						const need = (a.boxHeight + b.boxHeight) / 2 + LABEL_SPACING;
						if (b.adjustedY < a.adjustedY + need) b.adjustedY = a.adjustedY + need;
					}
				}

				// --- Si aún solapan tras resolución vertical, escalonar horizontalmente ---
				function resolveWithStagger(labelItems) {
					if (!labelItems.length) return;

					// Calcular si todas las etiquetas caben en el alto disponible del canvas
					const availH = isModalChart ? (chart.height - 4) * 0.76 : chart.height - 4;
					const totalH = labelItems.reduce((s, l) => s + l.boxHeight + LABEL_SPACING, 0);

					if (totalH <= availH) {
						// Caben en una sola columna: resolver solapamientos y listo
						resolveOverlaps(labelItems);
						if (isModalChart && labelItems.length > 4) {
							labelItems.forEach((label, index) => {
								if (index % 2 === 1) {
									const sign = label.isRight ? 1 : -1;
									label.labelX += sign * TIER_X_STEP;
									if (label.isRight) label.labelX = Math.min(label.labelX, chart.width - 6);
									else label.labelX = Math.max(label.labelX, 6);
									label.tier = 1;
								}
							});
							const tier0 = labelItems.filter((l) => !l.tier);
							const tier1 = labelItems.filter((l) => l.tier);
							resolveOverlaps(tier0);
							resolveOverlaps(tier1.sort((a, b) => a.naturalY - b.naturalY));
						}
						return;
					}

					// No caben en una columna: calcular cuántas columnas (tiers) son necesarias
					// para que cada una quepa en el alto disponible, distribuyendo etiquetas en round-robin.
					let nTiers = 2;
					while (nTiers < 4) {
						const tierHeights = Array(nTiers).fill(0);
						for (let i = 0; i < labelItems.length; i++) {
							const label = labelItems[i];
							tierHeights[i % nTiers] += label.boxHeight + LABEL_SPACING;
						}
						if (Math.max(...tierHeights) <= availH) break;
						nTiers++;
					}

					// Asignar cada etiqueta a su tier (round-robin por posición vertical)
					// y desplazar horizontalmente según el tier.
					labelItems.forEach((label, index) => {
						const tier = index % nTiers;
						label.tier = tier;
						if (tier > 0) {
							const sign = label.isRight ? 1 : -1;
							label.labelX += sign * TIER_X_STEP * tier;
							if (label.isRight) label.labelX = Math.min(label.labelX, chart.width - 6);
							else label.labelX = Math.max(label.labelX, 6);
						}
					});

					// Resolver solapamientos verticales dentro de cada tier por separado
					for (let t = 0; t < nTiers; t++) {
						const tierLabels = labelItems.filter((l) => l.tier === t).sort((a, b) => a.naturalY - b.naturalY);
						resolveOverlaps(tierLabels);
					}
				}

				resolveWithStagger(outsideLabels.filter((l) => l.isRight).sort((a, b) => a.naturalY - b.naturalY));
				resolveWithStagger(outsideLabels.filter((l) => !l.isRight).sort((a, b) => a.naturalY - b.naturalY));

				// --- Dibujar etiquetas exteriores (2 pasadas: conectores primero, cajas y texto después) ---

				// Pasada 1: todos los conectores (quedan debajo de las cajas)
				outsideLabels.forEach(({ arc, midAngle, labelX, adjustedY, line1, line2, fontSize, color }) => {
					const fs2 = line2 ? Math.max(fontSize - 1, 7) : fontSize;
					pluginCtx.save();
					pluginCtx.font = `bold ${fontSize}px ${CHART_FONT_FAMILY}`;
					const w1 = pluginCtx.measureText(line1).width;
					pluginCtx.font = `${fs2}px ${CHART_FONT_FAMILY}`;
					const w2 = line2 ? pluginCtx.measureText(line2).width : 0;
					const textWidth = Math.max(w1, w2);
					const isRight = Math.cos(midAngle) >= 0;
					const labelY = adjustedY;
					const lineStartX = arc.x + Math.cos(midAngle) * (arc.outerRadius + 2);
					const lineStartY = arc.y + Math.sin(midAngle) * (arc.outerRadius + 2);
					const elbowX = arc.x + Math.cos(midAngle) * (arc.outerRadius + (isModalChart ? 24 : 14));
					const elbowY = arc.y + Math.sin(midAngle) * (arc.outerRadius + (isModalChart ? 24 : 14));
					const boxEdgeX = isRight ? labelX - textWidth / 2 - PAD - 2 : labelX + textWidth / 2 + PAD + 2;
					pluginCtx.beginPath();
					pluginCtx.moveTo(lineStartX, lineStartY);
					pluginCtx.lineTo(elbowX, elbowY);
					pluginCtx.lineTo(boxEdgeX, labelY);
					pluginCtx.strokeStyle = color;
					pluginCtx.lineWidth = isModalChart ? 2 : 1.5;
					pluginCtx.stroke();
					pluginCtx.restore();
				});

				// Pasada 2: todas las cajas y textos (encima de los conectores)
				outsideLabels.forEach(({ labelX, adjustedY, line1, line2, fontSize, lineHeight, boxHeight }) => {
					pluginCtx.save();
					pluginCtx.textAlign = 'center';
					pluginCtx.textBaseline = 'middle';

					const fs2 = line2 ? Math.max(fontSize - 1, 7) : fontSize;
					pluginCtx.font = `bold ${fontSize}px ${CHART_FONT_FAMILY}`;
					const w1 = pluginCtx.measureText(line1).width;
					pluginCtx.font = `${fs2}px ${CHART_FONT_FAMILY}`;
					const w2 = line2 ? pluginCtx.measureText(line2).width : 0;
					const textWidth = Math.max(w1, w2);
					const labelY = adjustedY;
					const offsetY = line2 ? lineHeight / 2 : 0;

					// Caja
					pluginCtx.fillStyle = 'rgba(255, 255, 255, 0.92)';
					pluginCtx.strokeStyle = '#cccccc';
					pluginCtx.lineWidth = 1;
					pluginCtx.beginPath();
					pluginCtx.roundRect(labelX - textWidth / 2 - PAD, labelY - boxHeight / 2, textWidth + PAD * 2, boxHeight, 4);
					pluginCtx.fill();
					pluginCtx.stroke();

					// Línea 1: valor (negrita, arriba)
					pluginCtx.font = `bold ${fontSize}px ${CHART_FONT_FAMILY}`;
					pluginCtx.fillStyle = '#222222';
					pluginCtx.fillText(line1, labelX, labelY - offsetY);

					// Línea 2: porcentaje (normal, abajo)
					if (line2) {
						pluginCtx.font = `${fs2}px ${CHART_FONT_FAMILY}`;
						pluginCtx.fillStyle = '#666666';
						pluginCtx.fillText(line2, labelX, labelY + offsetY);
					}

					pluginCtx.restore();
				});
			}
		};

		this._centerTextPlugin = centerTextPlugin;
		this._sectorLabelsPlugin = sectorLabelsPlugin;

		if (this.chart) {
			this.chart.data.labels = labels;
			this.chart.data.datasets[0].data = values;
			this.chart.data.datasets[0].backgroundColor = colors;
			this.chart.data.datasets[0].borderColor = '#222';
			this.chart.data.datasets[0].borderWidth = 0.5;
			this.chart.update();
		} else {
			this.chart = new window.Chart(ctx, {
				type: valueChartType,
				data: {
					labels: labels,
					datasets: [
						{
							data: values,
							backgroundColor: colors,
							borderColor: '#222',
							borderWidth: 0.5,
							hoverOffset: 10,
							hoverBorderWidth: 1,
							hoverBorderColor: '#222'
						}
					]
				},
				options: {
					layout: {
						padding: this.labelsVisible ? 30 : 20
					},
					responsive: true,
					maintainAspectRatio: false,
					radius: '100%',
					cutout: '60%',
					plugins: {
						tooltip: {
							backgroundColor: 'rgba(55, 55, 55, 0.96)',
							titleColor: '#ffffff',
							bodyColor: '#ffffff',
							callbacks: {
								title: () => this.legendTitle || '',
								label: (context) => {
									const chart = context.chart;
									const data = Array.isArray(context.dataset.data) ? context.dataset.data : [];
									const total = data.reduce((sum, item, i) => {
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
									const formattedValue = formatter.format(currentValue);

									const line1 = `${context.label}: ${formattedValue}`;
									return showPercentInTotal ? [line1] : [line1, `(${formattedPercent}% de ${formattedTotal})`];
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
							boxPadding: 4
						},
						legend: {
							display: false
						}
					},
					animation: {
						animateScale: true,
						animateRotate: true
					}
				},
				plugins: [centerTextPlugin, sectorLabelsPlugin]
			});
		}

		this.isLoading = false;
		this.buildLegendItems(labels, values);

		// Direct mousemove listener for reliable pointer cursor on chart segments
		const canvasEl = this.template.querySelector('canvas');
		if (canvasEl && !canvasEl._cursorListenerAttached) {
			canvasEl._cursorListenerAttached = true;
			canvasEl.addEventListener('mousemove', (e) => {
				if (!this.chart) return;
				const points = this.chart.getElementsAtEventForMode(e, 'nearest', { intersect: true }, false);
				canvasEl.style.cursor = points.length > 0 ? 'pointer' : 'default';
			});
			canvasEl.addEventListener('mouseleave', () => {
				canvasEl.style.cursor = 'default';
			});
		}
	}

	get hasLegendItems() {
		return Array.isArray(this.legendItems) && this.legendItems.length > 0;
	}

	buildLegendItems(labels, values) {
		const colors = this._resolvedColors || this.colors;
		const total = values.reduce((sum, value, index) => {
			const isVisible = !this.chart || this.chart.getDataVisibility(index);
			return sum + (isVisible ? Number(value) || 0 : 0);
		}, 0);
		const valueFormatter = new Intl.NumberFormat(currentLanguage, { maximumFractionDigits: 2 });
		const percentageFormatter = new Intl.NumberFormat(currentLanguage, { maximumFractionDigits: 1 });
		const labelStyle = `max-width: ${Number(this.legendMaxTextWidth) || 170}px`;

		this.legendItems = labels.map((label, i) => ({
			label,
			value: this.chart && !this.chart.getDataVisibility(i) ? '' : valueFormatter.format(Number(values[i]) || 0),
			percentage:
				this.chart && !this.chart.getDataVisibility(i)
					? ''
					: `${percentageFormatter.format(total > 0 ? ((Number(values[i]) || 0) / total) * 100 : 0)}%`,
			labelStyle,
			index: i,
			hidden: this.chart ? !this.chart.getDataVisibility(i) : false,
			colorStyle: `background-color: ${colors[i % colors.length]}`,
			labelClass: this.chart && !this.chart.getDataVisibility(i) ? 'legend-label legend-label--hidden' : 'legend-label'
		}));
	}

	handleLegendClick(event) {
		const index = Number(event.currentTarget.dataset.index);
		if (!this.chart) return;
		this.chart.toggleDataVisibility(index);
		this.chart.update();
		if (this.modalChart) {
			this.modalChart.toggleDataVisibility(index);
			this.modalChart.update();
		}
		this.buildLegendItems(this._originalLabels, this._lastChartData.values);
	}

	get labelsToggleTitle() {
		return this.labelsVisible ? this.hideValuesLabel : this.showValuesLabel;
	}

	toggleLabels() {
		this.labelsVisible = !this.labelsVisible;
		this.chart?.update();
		if (this.modalChart) this.modalChart.update();
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
		const canvasEl = this.template.querySelector('canvas.modal-canvas');
		if (!canvasEl || !this._lastChartData || !this._centerTextPlugin || !this._sectorLabelsPlugin) return;

		if (this.modalChart) {
			this.modalChart.destroy();
			this.modalChart = null;
		}

		const ctx = canvasEl.getContext('2d');
		const { labels, values, valueChartType } = this._lastChartData;
		const resolvedColors = this._resolvedColors || this.colors;
		const self = this;

		this.modalChart = new window.Chart(ctx, {
			type: valueChartType,
			data: {
				labels: labels,
				datasets: [
					{
						data: values,
						backgroundColor: resolvedColors,
						borderColor: '#222',
						borderWidth: 0.5,
						hoverOffset: 10,
						hoverBorderWidth: 1,
						hoverBorderColor: '#222'
					}
				]
			},
			options: {
				layout: { padding: 80 },
				responsive: true,
				maintainAspectRatio: false,
				radius: '100%',
				cutout: '60%',
				plugins: {
					tooltip: {
						backgroundColor: 'rgba(55, 55, 55, 0.96)',
						titleColor: '#ffffff',
						bodyColor: '#ffffff',
						callbacks: {
							title: () => self.legendTitle || '',
							label: (context) => {
								const chart = context.chart;
								const data = Array.isArray(context.dataset.data) ? context.dataset.data : [];
								const total = data.reduce((sum, item, i) => sum + (chart.getDataVisibility(i) ? Number(item) || 0 : 0), 0);
								const currentValue = Number(context.raw) || 0;
								const percent = total > 0 ? (currentValue / total) * 100 : 0;
								const formatter = new Intl.NumberFormat(currentLanguage, { notation: 'compact', compactDisplay: 'short' });
								const line1 = `${context.label}: ${formatter.format(currentValue)}`;
								return self._showPercentInTotal
									? [line1]
									: [line1, `(${formatter.format(percent)}% de ${formatter.format(total)})`];
							}
						},
						titleFont: { size: 14, weight: 'bold' },
						bodyFont: { size: 12 },
						padding: 12,
						cornerRadius: 8,
						displayColors: true,
						boxPadding: 4
					},
					legend: { display: false }
				},
				animation: false
			},
			plugins: [this._centerTextPlugin, this._sectorLabelsPlugin]
		});

		// Sincronizar visibilidad de forma síncrona (sin animación no hay race condition)
		this.legendItems.forEach((item) => {
			if (item.hidden) {
				this.modalChart.toggleDataVisibility(item.index);
			}
		});
		if (this.legendItems.some((item) => item.hidden)) {
			this.modalChart.update('none');
		}

		// Re-habilitar animación para interacciones posteriores (toggle de leyenda, etc.)
		this.modalChart.options.animation = { animateScale: true, animateRotate: true };
	}
}