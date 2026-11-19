import { LightningElement } from 'lwc';

export default class Vl_CaseListView extends LightningElement {
	title = 'Casos';
	connectedCallback() {
		document.title = this.title;
	}
}