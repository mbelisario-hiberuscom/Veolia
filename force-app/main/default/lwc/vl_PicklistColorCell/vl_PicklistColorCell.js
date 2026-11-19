import { LightningElement, api } from 'lwc';

const COLOR_CLASS_BY_TOKEN = {
	red: 'red',
	amber: 'amber',
	green: 'green',
	blue: 'blue',
	orange: 'orange',
	neutral: 'neutral'
};

export default class VlPicklistColorCell extends LightningElement {
	@api value;
	@api label;
	@api colorValue;

	get displayValue() {
		return this.label || this.value || '';
	}

	get hasValue() {
		return String(this.displayValue).trim() !== '';
	}

	get badgeClass() {
		const normalizedColor = String(this.colorValue || '')
			.trim()
			.toLowerCase();
		return `picklist-color-badge picklist-color-badge_${COLOR_CLASS_BY_TOKEN[normalizedColor] || 'neutral'}`;
	}

	get ariaLabel() {
		return this.displayValue || 'Sin valor';
	}
}