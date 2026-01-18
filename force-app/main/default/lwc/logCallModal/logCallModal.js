import { LightningElement, track } from 'lwc';

export default class LogCallModal extends LightningElement {
    @track subject = '';
    @track notes = '';
    @track callResult = '';
    @track isSubmitting = false;

    callResultOptions = [
        { label: 'Connected', value: 'Connected' },
        { label: 'Left Voicemail', value: 'Left Voicemail' },
        { label: 'No Answer', value: 'No Answer' },
        { label: 'Busy', value: 'Busy' },
        { label: 'Wrong Number', value: 'Wrong Number' },
        { label: 'Positive', value: 'Positive' },
        { label: 'Negative', value: 'Negative' },
        { label: 'Neutral', value: 'Neutral' }
    ];

    get isSubmitDisabled() {
        return !this.subject || this.isSubmitting;
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handleNotesChange(event) {
        this.notes = event.target.value;
    }

    handleCallResultChange(event) {
        this.callResult = event.detail.value;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSave() {
        if (!this.subject) {
            return;
        }

        this.isSubmitting = true;
        
        this.dispatchEvent(new CustomEvent('save', {
            detail: {
                subject: this.subject,
                notes: this.notes,
                callResult: this.callResult
            }
        }));
    }

    // Prevent modal from closing when clicking inside
    handleModalClick(event) {
        event.stopPropagation();
    }
}
