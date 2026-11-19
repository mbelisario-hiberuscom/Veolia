import { api, track, wire } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import fullCalendar from '@salesforce/resourceUrl/fullcalendar702';
import fetchEvents from '@salesforce/apex/FWCCAL_CustomCalendarController.getEventsWithFrequency';
import fwccal_customCalendarBase from 'c/fwccal_customCalendarBase';
import LOCALE from '@salesforce/i18n/locale';
import LANG from '@salesforce/i18n/lang';
import FWCCAL_TitleColumn from '@salesforce/label/c.FWCCAL_TitleColumn';
import FWCCAL_ViewAction from '@salesforce/label/c.FWCCAL_ViewAction';

import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import WORKORDER_OBJECT from '@salesforce/schema/WorkOrder';

export default class fwccal_customCalendar extends fwccal_customCalendarBase {
	@api recordId;
	@api controllerClass;
	@api eventColor = 'Blue';
	@api pastMonths = 6;
	@api futureMonths = 6;
	@api eventLimit = 1000;
	@api whatId = '';
	@api whoId = '';
	@api ownerId = '';
	@api timezoneLabelsJSON = '';
	@api overrideTimezoneList = false;
	@api listofTimezonesOverride =
		'America/Los_Angeles,America/Chicago,America/Denver,America/Indianapolis,GMT,Europe/London,Europe/Paris,Asia/Jakarta,Asia/Makassar,Asia/Jayapura,Asia/Kolkata,Asia/Tokyo,Australia/Sydney,Australia/Darwin,Australia/Perth';
	@api hideEventDetailButton = false;
	@api eventDetailButtonText = 'More Info';
	@api hideTimezonePicklist = false;
	@api showWeekends = false;
	@api hideMonthView = false;
	@api hideWeekView = false;
	@api hideDayView = false;
	@api hideListView = false;
	@api rangeFrequency = 'MONTH';
	@api buttonsOnBottom = false;
	@api truncate = false;
	@api truncateEachLine = false;
	@api truncateNumberOfLinesToDisplay = 3;
	@api groupByType = false;

	@track calendar;
	@track items;
	@track itemsMap;
	@track timezoneList;
	@track timezoneObjList;
	@track selectedEvent;
	@track eventDetailsModalOpen = false;
	@track groupedEventsModalOpen = false;
	@track selectedGroupEvents = [];
	@track selectedGroupTitle = '';
	@track dayEventsModalOpen = false;
	@track selectedDayGroups = [];
	@track selectedDayTitle = '';
	@track escListener;
	@track selectedViews = [];
	@track hiddenEventTypesList = [];
	hiddenEventTypes = new Set();
	loadedMonthKey;
	pendingMonthKey;
	currentViewDate;
	// Mapa de referencias directas a los elementos DOM de los eventos montados.
	// LWC con lwc:dom="manual" puede hacer que querySelector no encuentre los
	// elementos hijos del contenedor del calendario, así que guardamos una
	// referencia directa a cada info.el en eventDidMount.
	eventElByEventId = new Map();

	businessAreaLegend = [];
	statusLegend = [];

	userLocale = LOCALE;
	userLanguage = LANG;

	isLoading = false;

	allViewsList = ['dayGridMonth', 'timeGridWeek', 'timeGridDay', 'listWeek'];
	navigationRange;

	get businessAreaLegendItems() {
		if (!this.businessAreaLegend || this.businessAreaLegend.length === 0) return [];
		const hiddenTypes = new Set(this.hiddenEventTypesList || []);
		const seen = {};
		this.businessAreaLegend.forEach((item) => {
			const key = Object.keys(item)[0];
			const value = item[key];

			if (!seen[key]) {
				const hidden = hiddenTypes.has(this.normalizeEventType(key));
				seen[key] = {
					type: key,
					hidden,
					colorStyle: `display:inline-block;width:12px;height:12px;border-radius:2px;background-color:${value};`,
					labelClass: hidden ? 'legend-text legend-text--hidden' : 'legend-text'
				};
			}
		});

		return Object.values(seen);
	}

	get statusLegendItems() {
		if (!this.statusLegend || this.statusLegend.length === 0) return [];
		const seen = {};
		this.statusLegend.forEach((item) => {
			const key = Object.keys(item)[0];
			const value = item[key];

			if (!seen[key]) {
				seen[key] = {
					type: key,
					cssClass: 'fc-has-icon ' + this.formatIconName(value)
				};
			}
		});

		return Object.values(seen);
	}

	get hasLegend() {
		return this.businessAreaLegendItems.length > 0 || this.statusLegendItems.length > 0;
	}

	@wire(getObjectInfo, { objectApiName: WORKORDER_OBJECT })
	objectInfo;

	get effectiveWhatId() {
		return this.whatId === 'recordId' ? this.recordId : this.whatId;
	}

	get effectiveWhoId() {
		return this.whoId === 'recordId' ? this.recordId : this.whoId;
	}

	get effectiveOwnerId() {
		return this.ownerId === 'recordId' ? this.recordId : this.ownerId;
	}

	get workOrderStatusLabel() {
		return this.objectInfo?.data?.fields?.CX_StatusSel__c?.label;
	}

	renderedCallback() {
		if (
			this.hideTimezonePicklist === false &&
			this.template.querySelector('.timezonePicklist') !== undefined &&
			this.template.querySelector('.timezonePicklist') !== null &&
			this.template.querySelector('.timezonePicklist').placeholder === 'Choose Timezone'
		) {
			this.template.querySelector('.timezonePicklist').placeholder = this.timezone;
		}
	}

	connectedCallback() {
		this.isLoading = true;
		this.hiddenEventTypes = new Set();
		this.hiddenEventTypesList = [];
		this.escListener = this.handleEscListener.bind(this);
		document.addEventListener('keydown', this.escListener);

		// FullCalendar v7: load standard bundle, classic theme JS, skeleton + theme CSS + palette
		// El archivo locales-all/global.js contiene TODOS los locales (es, en, fr, pl, ...).
		// Si no se carga, FullCalendar solo tiene el locale inglés por defecto y el
		// `locale: this.userLanguage` no tiene efecto.
		//
		// IMPORTANTE - Orden de carga:
		//   fullcalendar.global.js define window.FullCalendar (núcleo).
		//   locales-all/global.js y themes/classic/global.js son IIFEs que leen de
		//   FullCalendar.Shared en el momento de su ejecución. Si se cargan en
		//   paralelo con Promise.all, el navegador puede ejecutarlos ANTES de que
		//   el núcleo esté definido, y el tema/locales no se registran (los estilos
		//   no se aplican). Por eso cargamos primero el núcleo y luego, en cadena,
		//   locales y tema. Los CSS no tienen dependencias, van en paralelo.
		const base = fullCalendar + '/fullcalendar-7.0.2/dist';
		loadScript(this, base + '/fullcalendar.global.js')
			.then(() =>
				Promise.all([
					loadScript(this, base + '/locales-all/global.js'),
					loadScript(this, base + '/themes/classic/global.js'),
					loadStyle(this, base + '/skeleton.css'),
					loadStyle(this, base + '/themes/classic/theme.css'),
					loadStyle(this, base + '/themes/classic/palette.css')
				])
			)
			.then(() => {
				try {
					// Verify FullCalendar is available globally
					if (typeof window.FullCalendar === 'undefined') {
						throw new Error('FullCalendar v7 library failed to load globally');
					}

					this.currentViewDate = new Date();
					this.loadEventsForMonth(this.currentViewDate, true);
				} catch (err3) {
					console.error('FullCalendar init error:', err3);
					this.isLoading = false;
					if (this.isInSitePreview()) {
						this.showToast('Error', this.convertErrorToJSONString(err3), 'error');
					}
				}
			})
			.catch((err4) => {
				console.error('FullCalendar load error:', err4);
				this.isLoading = false;
				if (this.isInSitePreview()) {
					this.showToast('Error', this.convertErrorToJSONString(err4), 'error');
				}
			});
	}

	loadEventsForMonth(targetDate, shouldRenderCalendar = false) {
		const requestedViewDate = targetDate instanceof Date ? new Date(targetDate.getTime()) : new Date(targetDate || new Date());
		const monthStart = this.getMonthStartDate(requestedViewDate);
		const monthKey = this.getMonthKey(monthStart);

		if (this.pendingMonthKey === monthKey) {
			return;
		}

		this.pendingMonthKey = monthKey;
		this.isLoading = true;

		fetchEvents({
			controllerClass: this.controllerClass,
			pastMonths: this.pastMonths,
			futureMonths: this.futureMonths,
			rangeFrequency: this.rangeFrequency,
			eventLimit: this.eventLimit,
			whatId: this.effectiveWhatId,
			whoId: this.effectiveWhoId,
			ownerId: this.effectiveOwnerId,
			recordId: this.recordId,
			referenceDate: this.formatLocalDate(monthStart)
		})
			.then((result) => {
				try {
					let res = JSON.parse(result);
					if (res.error === undefined || res.error === null || res.error.trim() === '') {
						this.loadedMonthKey = monthKey;
						this.currentViewDate = requestedViewDate;
						this.businessAreaLegend = res.businessAreaLegend || [];
						this.statusLegend = res.statusLegend || [];
						this.itemsMap = res.eventsMap || {};
						this.items = Object.keys(this.itemsMap)
							.map((key) => {
								return this.itemsMap[key];
							})
							.reverse();
						this.timezoneList = res.timezoneList || [];

						this.siteUrl = res.siteUrl !== undefined && res.siteUrl !== null && res.siteUrl.trim() !== '' ? res.siteUrl : '';

						this.populateTimezoneSelectList();
						this.populateCalendarEvents(this.items);

						if (shouldRenderCalendar || !this.calendar) {
							this.renderCalendar();
						} else {
							this.refreshCalendarEvents();
						}
					} else {
						console.log('Error: ' + res.error);
						if (this.isInSitePreview()) {
							this.showToast('Error', res.error, 'error');
						}
					}
				} catch (err1) {
					console.log(err1);
					if (this.isInSitePreview()) {
						this.showToast('Error', this.convertErrorToJSONString(err1), 'error');
					}
				}
			})
			.catch((err2) => {
				console.log(err2);
				if (this.isInSitePreview()) {
					this.showToast('Error', this.convertErrorToJSONString(err2), 'error');
				}
			})
			.finally(() => {
				this.pendingMonthKey = undefined;
				this.isLoading = false;
			});
	}

	refreshCalendarEvents() {
		if (!this.calendar) {
			return;
		}

		// FullCalendar v7: removeAllEvents/addEventSource no existen.
		// Iterar y eliminar cada evento, luego añadirlos de nuevo con addEvent().
		const events = this.calendar.getEvents() || [];
		events.forEach((event) => {
			event.remove();
		});

		const eventsArray = JSON.parse(JSON.stringify(this.events || []));
		eventsArray.forEach((eventObj) => {
			this.calendar.addEvent(eventObj);
		});

		this.applyEventTypeVisibility();
		this.enforceNavigationRange(this.calendar.view);
	}

	getMonthStartDate(value) {
		const dateValue = value instanceof Date ? value : new Date(value);
		return new Date(dateValue.getFullYear(), dateValue.getMonth(), 1, 0, 0, 0, 0);
	}

	getMonthKey(value) {
		return this.formatLocalDate(this.getMonthStartDate(value)).substring(0, 7);
	}

	populateTimezoneSelectList() {
		this.timezoneLabels = JSON.parse(this.timezoneLabelsJSON);
		this.timezoneObjList = new Array();
		let timezoneList = this.timezoneList;
		if (
			this.overrideTimezoneList &&
			this.listofTimezonesOverride !== undefined &&
			this.listofTimezonesOverride !== null &&
			this.listofTimezonesOverride.trim() !== ''
		) {
			timezoneList = this.listofTimezonesOverride.split(',');
		}

		for (let i = 0; i < timezoneList.length; i++) {
			timezoneList[i] = timezoneList[i].trim();
			let tz = {};
			tz.label =
				this.timezoneLabels[timezoneList[i]] !== undefined &&
				this.timezoneLabels[timezoneList[i]] !== null &&
				this.timezoneLabels[timezoneList[i]].trim() !== ''
					? this.timezoneLabels[timezoneList[i]]
					: timezoneList[i];
			tz.label = timezoneList[i] === this.localTimezone ? 'Local - ' + tz.label : tz.label;
			tz.value = timezoneList[i];

			this.timezoneObjList.push(tz);
		}
	}

	renderCalendar() {
		try {
			const eventsJSONObj = this.events;

			const selectedTimezone = this.timezone;

			const calendarEl = this.template.querySelector('[data-id="calendar"]');

			let calendar = this.calendar;
			const eventColor = this.eventColor;

			this.selectedViews = [];
			for (let i = 0; i < this.allViewsList.length; i++) {
				if (this.allViewsList[i] === 'dayGridMonth' && this.hideMonthView === false) {
					// && isMobile === false){
					this.selectedViews.push(this.allViewsList[i]);
				} else if (this.allViewsList[i] === 'timeGridWeek' && this.hideWeekView === false) {
					// && isMobile === false){
					this.selectedViews.push(this.allViewsList[i]);
				} else if (this.allViewsList[i] === 'timeGridDay' && this.hideDayView === false) {
					this.selectedViews.push(this.allViewsList[i]);
				} else if (this.allViewsList[i] === 'listWeek' && this.hideListView === false) {
					this.selectedViews.push(this.allViewsList[i]);
				}
			}

			let defaultView;
			if (this.selectedViews.length > 0) {
				defaultView = this.selectedViews[0];

				/*if(this.selectedViews.includes('listWeek') === false && this.selectedViews.includes('timeGridDay') === false){
					throw "You must choose at least one view to show on mobile (You cannot hide both Day and List views).";
				}

				if(isMobile === false){
					defaultView = this.selectedViews[0];
				}
				else if(isMobile === true && this.selectedViews.includes('listWeek') === true){
					defaultView = 'listWeek';
				}
				else if(isMobile === true && this.selectedViews.includes('timeGridDay') === true){
					defaultView = 'timeGridDay';
				}*/
			} else {
				throw new Error('You must choose at least one view to show.');
			}

			const headerRight = this.selectedViews.join(',');
			this.navigationRange = this.buildNavigationRange();

			if (calendar !== undefined && calendar !== null) {
				calendar.destroy();
			}

			calendar = new window.FullCalendar.Calendar(calendarEl, {
				initialView: defaultView,
				initialDate: this.currentViewDate,
				locale: this.userLanguage,
				firstDay: 1,
				eventColor: eventColor,
				eventContrastColor: '#000000',
				weekends: this.showWeekends,
				fixedWeekCount: false,
				height: 'auto',
				headerToolbar: {
					start: 'prev,next,today',
					center: 'title',
					end: headerRight
				},
				timeZone: selectedTimezone,
				validRange: {
					start: this.navigationRange.start,
					end: this.navigationRange.end
				},
				events: eventsJSONObj,
				// FullCalendar v7: los nombres de clase del tema (classic) están ofuscados
				// (fc-classic-XXX), por lo que no podemos apuntar a .fc-event-title ni a
				// .fc-title con CSS. La guía de migración v7 recomienda usar los hooks de
				// "settings" para añadir clases estables que después estilamos desde el CSS
				// del componente. Aquí añadimos las clases que el componente necesita para
				// iconos de evento, identificación de botones prev/next, cabeceras de día, etc.
				buttonClass: (info) => {
					const extra = [];
					if (info.name === 'prev') extra.push('cx-cal-prev-button');
					if (info.name === 'next') extra.push('cx-cal-next-button');
					if (info.name === 'today') extra.push('cx-cal-today-button');
					// Botones de vista (dayGridMonth, timeGridWeek, timeGridDay, listWeek)
					if (info.name !== 'prev' && info.name !== 'next' && info.name !== 'today') {
						extra.push('cx-cal-view-button');
					}
					return extra.join(' ');
				},
				toolbarSectionClass: (info) => 'cx-cal-toolbar-section cx-cal-toolbar-' + info.name,
				// El título del toolbar se renderiza en un div hijo con clases del tema
				// classic ofuscadas (fc-classic-XXX) que aplican font-weight: bold entre
				// otros estilos. Añadimos una clase estable para poder sobreescribirlo.
				toolbarTitleClass: () => 'cx-cal-toolbar-title',
				dayHeaderClass: () => 'cx-cal-day-header',
				// Vista de lista (listWeek): los eventos se agrupan por día. FullCalendar
				// renderiza un contenedor por día (listDayClass) con data-date, y dentro una
				// cabecera (listDayHeaderClass) que muestra la fecha. Añadimos clases
				// estables para poder estilarlas desde el CSS del componente, ya que las
				// clases del tema classic están ofuscadas (fc-classic-XXX).
				listDayClass: () => 'cx-cal-list-day',
				listDayHeaderClass: () => 'cx-cal-list-day-header',
				eventClass: () => 'cx-cal-event',
				// Eventos en bloque (vista de mes/día): añadimos una clase específica
				// para poder aplicar el borde solo a estos y no a los de la vista de lista.
				blockEventClass: () => 'cx-cal-event-block',
				eventInnerClass: () => 'cx-cal-event-main',
				eventTimeClass: () => 'cx-cal-event-time',
				eventTitleClass: (info) => {
					// Añadimos las clases de icono directamente al elemento de título.
					// eventDidMount no se vuelve a invocar cuando cambia el dato del evento,
					// pero eventTitleClass sí se reevalúa, así que es más robusto que
					// buscar el elemento a mano en el DOM.
					const classes = ['cx-cal-event-title'];
					const icon = info.event?.extendedProps?.iconName;
					if (icon) {
						classes.push('fc-has-icon');
						classes.push(this.formatIconName(icon));
					}
					return classes.join(' ');
				},
				datesSet: (info) => {
					this.enforceNavigationRange(info.view);
					this.handleViewMonthChange(info.view);
				},
				dateClick: (info) => {
					try {
						if (this.groupByType) {
							this.handleDayClick(info.dateStr);
						}
					} catch (err) {
						console.error('dateClick error:', err);
					}
				},
				eventDidMount: (info) => {
					try {
						// Native DOM API instead of jQuery.
						// IMPORTANTE: la clase eventPopover-{id} se añade SIEMPRE, incluso si el
						// evento va a estar oculto. Así applyEventTypeVisibility puede localizar
						// el elemento del DOM para toggle su visibilidad cuando cambie la leyenda.
						info.el.classList.add('eventPopover-' + info.event.id);
						info.el.setAttribute('data-event-id', info.event.id);

						// Guarda una referencia directa al elemento DOM del evento.
						// Esto evita problemas de querySelector en LWC con lwc:dom="manual".
						this.eventElByEventId.set(String(info.event.id), info.el);

						info.el.addEventListener('click', () => {
							this.handleEventClick({
								data: { info: info }
							});
						});

						info.el.setAttribute('title', info.event.title);

						// Evalúa si el evento debe estar oculto según el estado actual de la leyenda.
						// En v7 ya no existe "return false" en eventDidMount, así que ocultamos
						// añadiendo la clase cx-cal-event-hidden (definida en el CSS con
						// display:none !important para que FullCalendar no la sobreescriba).
						// applyEventTypeVisibility reutiliza esta misma evaluación para
						// mostrar/ocultar al pulsar la leyenda.
						const shouldHide = this.shouldHideEvent(info.event);

						if (shouldHide) {
							info.el.classList.add('cx-cal-event-hidden');
						}
					} catch (err) {
						console.error('eventDidMount error:', err);
						if (this.isInSitePreview()) {
							this.showToast('Error', this.convertErrorToJSONString(err), 'error');
						}
					}
				},
				eventWillUnmount: (info) => {
					// Limpia la referencia del Map cuando el evento se desmonta
					// (cambio de vista, navegación entre meses, refresco, etc.).
					this.eventElByEventId.delete(String(info.event.id));
				}
			});

			this.calendar = calendar;

			calendar.render();
			this.applyEventTypeVisibility();
			this.enforceNavigationRange(calendar.view);

			// FullCalendar v7: los botones ya no exponen .fc-button ni aria-label="prev".
			// Añadimos nuestras propias clases estables vía buttonClass y aquí simplemente
			// prevenimos el comportamiento nativo de mousedown para evitar el foco en click.
			const buttonList = this.template.querySelectorAll('[data-id="calendar"] button');
			for (let i = 0; i < buttonList.length; i++) {
				buttonList[i].addEventListener('mousedown', function (ev) {
					ev.preventDefault();
				});
			}
		} catch (err) {
			if (this.isInSitePreview()) {
				console.log(err);
				this.showToast('Error', this.convertErrorToJSONString(err), 'error');
			}
		}
	}

	handleViewMonthChange(view) {
		const currentDate = this.calendar?.getDate ? this.calendar.getDate() : view?.currentStart;
		const visibleMonth = currentDate ? this.getMonthStartDate(currentDate) : null;
		if (!visibleMonth) {
			return;
		}

		const visibleMonthKey = this.getMonthKey(visibleMonth);
		if (visibleMonthKey === this.loadedMonthKey || visibleMonthKey === this.pendingMonthKey) {
			return;
		}

		this.loadEventsForMonth(currentDate, false);
	}

	enforceNavigationRange(view) {
		if (!this.calendar || !this.navigationRange || !view) {
			return;
		}

		const viewStart = this.calendar.getDate ? this.calendar.getDate() : view.currentStart;
		if (!viewStart) {
			return;
		}

		// Use the calendar anchor date so week/day/list views crossing month boundaries map to the month the user is viewing.
		const visibleMonth = new Date(viewStart.getFullYear(), viewStart.getMonth(), 1, 0, 0, 0, 0);
		const rangeStart = new Date(this.navigationRange.start + 'T00:00:00');
		const rangeLastMonth = new Date(this.navigationRange.lastMonthStart + 'T00:00:00');

		// If we somehow moved before the first month with events, snap back.
		if (visibleMonth.getTime() < rangeStart.getTime()) {
			this.calendar.gotoDate(rangeStart);
			return;
		}

		// If we somehow moved after the last month with events, snap back.
		if (visibleMonth.getTime() > rangeLastMonth.getTime()) {
			this.calendar.gotoDate(rangeLastMonth);
			return;
		}

		const atStart = visibleMonth.getTime() === rangeStart.getTime();
		const atEnd = visibleMonth.getTime() === rangeLastMonth.getTime();
		this.setNavButtonState(atStart, atEnd);
	}

	setNavButtonState(atStart, atEnd) {
		// FullCalendar v7: los botones ya no tienen las clases .fc-prev-button /
		// .fc-next-button. Las añadimos vía el hook buttonClass.
		const prevButton = this.template.querySelector('.cx-cal-prev-button');
		const nextButton = this.template.querySelector('.cx-cal-next-button');

		if (prevButton) {
			prevButton.disabled = atStart;
			prevButton.classList.toggle('cx-cal-nav-disabled', atStart);
			prevButton.style.opacity = atStart ? '0.4' : '';
			prevButton.style.cursor = atStart ? 'not-allowed' : '';
		}

		if (nextButton) {
			nextButton.disabled = atEnd;
			nextButton.classList.toggle('cx-cal-nav-disabled', atEnd);
			nextButton.style.opacity = atEnd ? '0.4' : '';
			nextButton.style.cursor = atEnd ? 'not-allowed' : '';
		}
	}

	buildNavigationRangeFromEvents(events) {
		const inputEvents = Array.isArray(events) ? events : [];
		let minDate = null;
		let maxDate = null;

		inputEvents.forEach((evt) => {
			const startRaw = evt && (evt.start || evt.startDateTime);
			const endRaw = evt && (evt.end || evt.endDateTime);
			const startDate = startRaw ? new Date(startRaw) : null;
			const endDate = endRaw ? new Date(endRaw) : null;

			if (startDate && !Number.isNaN(startDate.getTime()) && (!minDate || startDate < minDate)) {
				minDate = startDate;
			}

			// Use start for the max-month decision so "months with events" is based on when events occur.
			const maxCandidate = startDate || endDate;
			if (maxCandidate && !Number.isNaN(maxCandidate.getTime()) && (!maxDate || maxCandidate > maxDate)) {
				maxDate = maxCandidate;
			}
		});

		if (!minDate || !maxDate) {
			return this.buildNavigationRange();
		}

		const startDate = new Date(minDate.getFullYear(), minDate.getMonth(), 1, 0, 0, 0, 0);
		const lastMonthStart = new Date(maxDate.getFullYear(), maxDate.getMonth(), 1, 0, 0, 0, 0);
		const endDate = new Date(maxDate.getFullYear(), maxDate.getMonth() + 1, 1, 0, 0, 0, 0);

		const range = {
			start: this.formatLocalDate(startDate),
			lastMonthStart: this.formatLocalDate(lastMonthStart),
			end: this.formatLocalDate(endDate)
		};

		return range;
	}

	formatLocalDate(date) {
		const year = date.getFullYear();
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const day = String(date.getDate()).padStart(2, '0');
		return `${year}-${month}-${day}`;
	}

	buildNavigationRange() {
		const today = new Date();
		const currentYear = today.getFullYear();
		const currentMonth = today.getMonth();

		const pastN = Number(this.pastMonths || 0);
		const futureN = Number(this.futureMonths || 0);

		const startDate = new Date(currentYear, currentMonth - pastN, 1, 0, 0, 0, 0);
		const lastMonthStart = new Date(currentYear, currentMonth + futureN, 1, 0, 0, 0, 0);
		const endDate = new Date(lastMonthStart.getFullYear(), lastMonthStart.getMonth() + 1, 1, 0, 0, 0, 0);

		const range = {
			start: this.formatLocalDate(startDate),
			lastMonthStart: this.formatLocalDate(lastMonthStart),
			end: this.formatLocalDate(endDate)
		};

		return range;
	}

	normalizeEventType(value) {
		if (value === undefined || value === null) {
			return '';
		}

		return String(value)
			.normalize('NFD')
			.replace(/[\u0300-\u036f]/g, '')
			.replace(/\s+/g, ' ')
			.trim()
			.toLocaleUpperCase(this.userLanguage || undefined);
	}

	normalizeColor(value) {
		if (!value) {
			return '';
		}

		const raw = String(value).trim().toLowerCase();
		if (!raw) {
			return '';
		}

		if (raw.startsWith('#')) {
			if (raw.length === 4) {
				return `#${raw[1]}${raw[1]}${raw[2]}${raw[2]}${raw[3]}${raw[3]}`;
			}
			return raw;
		}

		const rgbMatch = raw.match(/rgba?\(([^)]+)\)/);
		if (rgbMatch && rgbMatch[1]) {
			const rgbParts = rgbMatch[1]
				.split(',')
				.slice(0, 3)
				.map((part) => {
					const num = Number(String(part).trim());
					return Number.isFinite(num) ? Math.max(0, Math.min(255, Math.round(num))) : 0;
				});

			if (rgbParts.length === 3) {
				return `#${rgbParts
					.map((num) => {
						const hex = num.toString(16);
						return hex.length === 1 ? '0' + hex : hex;
					})
					.join('')}`;
			}
		}

		return raw.replace(/\s+/g, '');
	}

	getNormalizedBusinessAreaTypes() {
		const normalizedTypes = new Set();
		(this.businessAreaLegend || []).forEach((item) => {
			const key = Object.keys(item || {})[0];
			if (key) {
				normalizedTypes.add(this.normalizeEventType(key));
			}
		});
		return normalizedTypes;
	}

	getBusinessAreaColorByType() {
		const colorByType = new Map();
		(this.businessAreaLegend || []).forEach((item) => {
			const key = Object.keys(item || {})[0];
			if (!key) {
				return;
			}

			const normalizedType = this.normalizeEventType(key);
			const color = this.normalizeColor(item[key]);
			if (normalizedType && color) {
				colorByType.set(normalizedType, color);
			}
		});

		return colorByType;
	}

	resolveEventTypeByLegend(rawType, rawTitle) {
		const normalizedType = this.normalizeEventType(rawType);
		const normalizedTitle = this.normalizeEventType(rawTitle);
		const businessTypes = Array.from(this.getNormalizedBusinessAreaTypes());

		if (normalizedType && businessTypes.includes(normalizedType)) {
			return normalizedType;
		}

		for (let i = 0; i < businessTypes.length; i++) {
			const candidate = businessTypes[i];
			if (normalizedTitle === candidate || normalizedTitle.startsWith(candidate + ':') || normalizedTitle.startsWith(candidate + ' -')) {
				return candidate;
			}
		}

		return normalizedType || normalizedTitle;
	}

	getEventTypeFromCalendarEvent(calendarEvent) {
		if (!calendarEvent) {
			return null;
		}

		const rawType = calendarEvent.extendedProps?.type || calendarEvent.type;
		const rawTitle = calendarEvent.title || '';
		const cleanedTitle = String(rawTitle)
			.replace(/\s\(\d+\)$/, '')
			.trim();
		const resolved = this.resolveEventTypeByLegend(rawType, cleanedTitle);
		return resolved || null;
	}

	/**
	 * Determina si un evento del calendario debe estar oculto según el estado
	 * actual de la leyenda (businessAreaLegend). Centraliza la lógica de
	 * filtrado para que eventDidMount y applyEventTypeVisibility evalúen
	 * exactamente las mismas condiciones.
	 */
	shouldHideEvent(calendarEvent) {
		if (!calendarEvent) {
			return false;
		}

		const hiddenTypes = this.hiddenEventTypes || new Set();
		if (hiddenTypes.size === 0) {
			return false;
		}

		const eventType = this.getEventTypeFromCalendarEvent(calendarEvent);
		const normalizedEventType = this.normalizeEventType(eventType);
		const eventColor = this.normalizeColor(
			calendarEvent.color ||
				calendarEvent.backgroundColor ||
				calendarEvent.extendedProps?.color ||
				calendarEvent.extendedProps?.backgroundColor ||
				calendarEvent.source?.color ||
				calendarEvent.source?.backgroundColor
		);

		const colorByType = this.getBusinessAreaColorByType();
		const hiddenColors = new Set(
			Array.from(hiddenTypes)
				.map((type) => colorByType.get(type))
				.filter((color) => !!color)
		);

		const hideByType = normalizedEventType && hiddenTypes.has(normalizedEventType);
		const hideByColor = Boolean(eventColor && hiddenColors.has(eventColor));
		const shouldHide = hideByType || hideByColor;

		return shouldHide;
	}

	applyEventTypeVisibility() {
		if (!this.calendar) {
			return;
		}

		const events = this.calendar.getEvents() || [];
		const calendarEl = this.template.querySelector('[data-id="calendar"]');

		events.forEach((calendarEvent) => {
			const shouldHide = this.shouldHideEvent(calendarEvent);

			// Estrategia 1: referencia directa guardada en eventDidMount (preferida).
			let eventEl = this.eventElByEventId.get(String(calendarEvent.id));

			// Estrategia 2 (fallback): querySelector sobre el contenedor del calendario.
			if (!eventEl && calendarEl) {
				eventEl = calendarEl.querySelector('.eventPopover-' + calendarEvent.id);
			}

			if (eventEl) {
				if (shouldHide) {
					eventEl.classList.add('cx-cal-event-hidden');
				} else {
					eventEl.classList.remove('cx-cal-event-hidden');
				}
			}
		});
	}

	updateLegendVisibilityState() {
		this.hiddenEventTypesList = Array.from(this.hiddenEventTypes);
	}

	handleBusinessAreaLegendClick(event) {
		const eventType = event.currentTarget?.dataset?.type;
		if (!eventType) {
			return;
		}

		const normalizedEventType = this.normalizeEventType(eventType);

		if (this.hiddenEventTypes.has(normalizedEventType)) {
			this.hiddenEventTypes.delete(normalizedEventType);
		} else {
			this.hiddenEventTypes.add(normalizedEventType);
		}

		this.updateLegendVisibilityState();
		this.applyEventTypeVisibility();
	}

	handleEventClick(e) {
		try {
			if (this.groupByType) {
				let groupId = e.data.info.event.id;
				let groupEvents = this.eventsMap[groupId];

				if (groupEvents && groupEvents.length === 1) {
					this.isLoading = true;
					window.top.location.href = groupEvents[0].detailsURL;
				} else if (groupEvents && groupEvents.length > 1) {
					this.selectedGroupEvents = groupEvents;
					this.selectedGroupTitle = e.data.info.event.title.replace(/ \(\d+\)$/, '');
					this.groupedEventsModalOpen = true;
				}
			} else {
				this.isLoading = true;
				let eventId = e.data.info.event.id;
				this.selectedEvent = this.eventsMap[eventId];

				window.top.location.href = this.selectedEvent.detailsURL;
			}
		} catch (err) {
			if (this.isInSitePreview()) {
				console.log(err);
				this.showToast('Error', this.convertErrorToJSONString(err), 'error');
			}
		}
	}

	closeEventDetailsModal() {
		this.eventDetailsModalOpen = false;
		this.selectedEvent = undefined;
	}

	closeGroupModal() {
		this.groupedEventsModalOpen = false;
		this.selectedGroupEvents = [];
		this.selectedGroupTitle = '';
	}

	get dtColumns() {
		return [
			{
				label: FWCCAL_TitleColumn,
				fieldName: 'title',
				type: 'text',
				wrapText: true,
				resizable: false,
				sortable: false,
				hideDefaultActions: true
			},
			{
				type: 'button',
				fixedWidth: 80,
				resizable: false,
				typeAttributes: { label: FWCCAL_ViewAction, name: 'view', variant: 'brand' }
			}
		];
	}

	handleRowAction(e) {
		const row = e.detail.row;
		if (row.detailsURL) {
			window.top.location.href = row.detailsURL;
		}
	}

	handleDayClick(dateStr) {
		let typeMap = {};
		for (let groupId in this.eventsMap) {
			if (!Object.prototype.hasOwnProperty.call(this.eventsMap, groupId)) {
				continue;
			}
			let groupEvents = this.eventsMap[groupId];
			if (Array.isArray(groupEvents)) {
				groupEvents.forEach((evt) => {
					if (evt.startDateTime && evt.startDateTime.substring(0, 10) === dateStr) {
						let evtType = evt.type || 'Other';
						if (!typeMap[evtType]) typeMap[evtType] = [];
						typeMap[evtType].push(evt);
					}
				});
			}
		}
		let groups = Object.keys(typeMap).map((type) => ({ type: type, events: typeMap[type] }));
		if (groups.length > 0) {
			this.selectedDayGroups = groups;
			const [year, month, day] = dateStr.split('-');
			this.selectedDayTitle = `${day}/${month}/${year}`;
			this.dayEventsModalOpen = true;
		}
	}

	closeDayModal() {
		this.dayEventsModalOpen = false;
		this.selectedDayGroups = [];
		this.selectedDayTitle = '';
	}

	handleEscListener(e) {
		if (e.keyCode === 27 && this.eventDetailsModalOpen === true) {
			this.closeEventDetailsModal();
		}
		if (e.keyCode === 27 && this.groupedEventsModalOpen === true) {
			this.closeGroupModal();
		}
		if (e.keyCode === 27 && this.dayEventsModalOpen === true) {
			this.closeDayModal();
		}
	}

	handleTimezoneChange(e) {
		this.timezone = e.detail.value;
		this.populateCalendarEvents(this.items);
		this.renderCalendar();
		const timeZoneEvent = new CustomEvent('CCCALENDAR_TIMEZONE_CHANGE', {
			detail: {
				timezone: this.timezone
			}
		});
		window.dispatchEvent(timeZoneEvent);
	}

	formatIconName(icon) {
		return icon.replace(':', '-');
	}

	//Function to show a message to the user
	showToast(title, message, variant) {
		const toastInfo = new ShowToastEvent({
			title: title,
			message: message,
			variant: variant
		});
		this.dispatchEvent(toastInfo);
	}
}