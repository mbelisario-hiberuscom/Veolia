import { LightningElement, api } from 'lwc';

export default class Fwccal_eventDetailsModal extends LightningElement {
	eventData;

	@api
	get event() {
		return this.eventData;
	}

	set event(value) {
		this.eventData = value;
	}

	@api
	get eventDetailSectionSize() {
		return this.event !== undefined &&
			this.event.eventImageURL !== undefined &&
			this.event.eventImageURL !== null &&
			this.event.eventImageURL.trim() !== ''
			? '8'
			: '12';
	}

	connectedCallback() {
		if (this.event !== undefined && this.event !== null) {
			this.eventData = JSON.parse(JSON.stringify(this.event));
		}
	}

	handleCloseDetailsModal(e) {
		e.preventDefault();
		const closeModalDetailsEvent = new CustomEvent('closedetailsmodalevent');
		this.dispatchEvent(closeModalDetailsEvent);
	}
}