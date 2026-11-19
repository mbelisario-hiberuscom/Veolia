import { api, track } from 'lwc';
import fetchUpcomingEvents from '@salesforce/apex/FWCCAL_CustomCalendarController.getUpcomingEvents';
import fwccal_customCalendarBase from 'c/fwccal_customCalendarBase';

export default class Fwccal_upcomingEvents extends fwccal_customCalendarBase {
	@api eventLimit = 10;
	@api controllerClass;
	@api whatId = '';
	@api whoId = '';
	@api ownerId = '';
	@api eventDetailButtonText = 'More Info';
	@api timezoneLabelsJSON = '';
	@api buttonsOnBottom = false;
	@api truncate = false;
	@api truncateEachLine = false;
	@api truncateNumberOfLinesToDisplay = 3;
	@api hideEventDetailButton = false;

	@track items;
	@track itemsMap;

	handleTimeZoneChangeBinded;

	connectedCallback() {
		this.handleTimeZoneChangeBinded = this.handleTimeZoneChange.bind(this);

		window.addEventListener('CCCALENDAR_TIMEZONE_CHANGE', this.handleTimeZoneChangeBinded, false);

		this.timezoneLabels = JSON.parse(this.timezoneLabelsJSON);

		fetchUpcomingEvents({
			eventLimit: this.eventLimit,
			whatId: this.whatId,
			whoId: this.whoId,
			ownerId: this.ownerId
		})
			.then((result) => {
				try {
					let res = JSON.parse(result);
					if (res.error === undefined || res.error === null || res.error.trim() === '') {
						this.itemsMap = res.eventsMap;
						this.items = Object.keys(this.itemsMap)
							.map((key) => {
								this.itemsMap[key].CX_Image_URL__c = undefined;
								return this.itemsMap[key];
							})
							.reverse();

						this.siteUrl = res.siteUrl !== undefined && res.siteUrl !== null && res.siteUrl.trim() !== '' ? res.siteUrl : '';

						this.populateCalendarEvents(this.items);
						this.items = this.events;
					} else {
						console.log('Error: ' + res.error);
						if (this.isInSitePreview()) {
							this.showToast('Error', this.convertErrorToJSONString(res.error), 'error');
						}
					}
				} catch (err1) {
					console.log(err1 + '');
					if (this.isInSitePreview()) {
						this.showToast('Error', this.convertErrorToJSONString(err1), 'error');
					}
				}
			})
			.catch((err2) => {
				console.log(err2 + '');
				if (this.isInSitePreview()) {
					this.showToast('Error', this.convertErrorToJSONString(err2), 'error');
				}
			});
	}

	disconnectedCallback() {
		window.removeEventListener('CCCALENDAR_TIMEZONE_CHANGE', this.handleTimeZoneChangeBinded, false);
	}

	handleTimeZoneChange(e) {
		try {
			this.timezone = e.detail.timezone;
			this.items = Object.keys(this.itemsMap)
				.map((key) => {
					this.itemsMap[key].CX_Image_URL__c = undefined;
					return this.itemsMap[key];
				})
				.reverse();
			this.populateCalendarEvents(this.items);
			this.items = this.events;
		} catch (err) {
			console.log(err);
		}
	}
}