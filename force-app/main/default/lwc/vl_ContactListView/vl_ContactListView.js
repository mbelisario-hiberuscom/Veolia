import { LightningElement } from 'lwc';

export default class Vl_ContactListView extends LightningElement {
	title = 'Contactos';
	connectedCallback() {
		document.title = this.title;
	}
}