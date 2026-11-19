import { LightningElement, api } from 'lwc';

export default class vlRatingCell extends LightningElement {
	@api value;

	get hasValue() {
		return this.value != null && this.value !== '';
	}

	get numericValue() {
		return this.hasValue ? Number(this.value) : null;
	}

	get hasValidValue() {
		return this.hasValue && Number.isFinite(this.numericValue);
	}

	get displayValue() {
		if (!this.hasValue) return '';
		if (!this.hasValidValue) return '#ERROR#';
		const numericValue = this.numericValue;
		return Number.isInteger(numericValue) ? String(numericValue) : numericValue.toFixed(1);
	}

	get normalizedScore() {
		if (!this.hasValidValue) return 0;
		return Math.max(0, Math.min(5, this.numericValue));
	}

	get dots() {
		const score = this.normalizedScore;
		const full = Math.floor(score);
		const half = score - full >= 0.5;
		const dots = [];
		for (let index = 0; index < 5; index++) {
			let state;
			if (index < full) {
				state = 'full';
			} else if (index === full && half) {
				state = 'half';
			} else {
				state = 'empty';
			}
			dots.push({
				index,
				className: `rating-dot rating-dot_${state} rating-dot_${this.tone}`
			});
		}
		return dots;
	}

	get tone() {
		const score = this.normalizedScore;
		if (score >= 4) return 'good';
		if (score >= 2.5) return 'warning';
		return 'bad';
	}

	get ariaLabel() {
		if (!this.hasValue) return 'Sin valor';
		if (!this.hasValidValue) return '#ERROR#';
		return `${this.displayValue} de 5`;
	}

	get tooltip() {
		return this.ariaLabel;
	}
}