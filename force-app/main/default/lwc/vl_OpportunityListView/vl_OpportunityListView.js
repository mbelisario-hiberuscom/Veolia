import { LightningElement } from 'lwc';

export default class VlOpportunityListView extends LightningElement {
	title = 'Oportunidades';
	connectedCallback() {
		document.title = this.title;
	}
}