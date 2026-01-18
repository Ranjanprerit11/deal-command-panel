import { LightningElement, api } from 'lwc';

export default class DealQuickActions extends LightningElement {
    @api nextStepValue = '';
    @api isEditingNextStep = false;

    _localNextStepValue = '';

    connectedCallback() {
        this._localNextStepValue = this.nextStepValue;
    }

    renderedCallback() {
        if (!this.isEditingNextStep) {
            this._localNextStepValue = this.nextStepValue;
        }
    }

    get displayNextStep() {
        return this.nextStepValue || 'No next step defined';
    }

    get nextStepIsEmpty() {
        return !this.nextStepValue;
    }

    get nextStepDisplayClass() {
        return this.nextStepIsEmpty ? 'next-step-empty' : 'next-step-value';
    }

    get showEditButton() {
        return !this.isEditingNextStep;
    }

    handleCreateTask() {
        this.dispatchEvent(new CustomEvent('taskcreate'));
    }

    handleLogCall() {
        this.dispatchEvent(new CustomEvent('logcall'));
    }

    handleEditNextStep() {
        this._localNextStepValue = this.nextStepValue;
        this.dispatchEvent(new CustomEvent('editnextstep'));
    }

    handleNextStepInput(event) {
        this._localNextStepValue = event.target.value;
        this.dispatchEvent(new CustomEvent('nextstepchange', {
            detail: { value: event.target.value }
        }));
    }

    handleSaveNextStep() {
        this.dispatchEvent(new CustomEvent('savenextstep', {
            detail: { value: this._localNextStepValue }
        }));
    }

    handleCancelNextStep() {
        this._localNextStepValue = this.nextStepValue;
        this.dispatchEvent(new CustomEvent('cancelnextstep'));
    }

    handleCreateEmail() {
        // For now, just open the AI assist section
        // Could also open default email client
        this.dispatchEvent(new CustomEvent('createemail'));
    }
}
