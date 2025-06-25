import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getJobById from '@salesforce/apex/JobController.getJobById';
import applyForJob from '@salesforce/apex/JobController.applyForJob';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ApplyJobPage extends LightningElement {
    @track job;
    @track error;
    @track message;
    
    @track jobId;

    @track firstName = '';
    @track lastName = '';
    @track coverLetter = '';
    @track resumeContentDocumentId = '';


    candidateEmail = window.localStorage.getItem('candidateEmail') || '';

    // Get jobId from page URL
    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        this.jobId = pageRef?.state?.c__jobId;
    }

    // Fetch job details by jobId
    @wire(getJobById, { jobId: '$jobId' })
    wiredJob({ data, error }) {
        if (data) {
            this.job = data;
            this.error = undefined;
        } else if (error) {
            this.error = 'Could not load job details.';
            this.job = undefined;
        }
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        this[name] = value;
    }
    
    handleUploadFinished(event) {
        // Capture uploaded file's ContentDocumentId (assuming Salesforce Files)
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.resumeContentDocumentId = uploadedFiles[0].documentId;
        }
    }

    handleApply() {
        if (!this.candidateEmail) {
            this.error = 'You must be logged in to apply.';
            return;
        }

        applyForJob({
            jobId: this.jobId,
            candidateEmail: this.candidateEmail,
            firstName: this.firstName,
            lastName: this.lastName,
            coverLetter: this.coverLetter,
            resumeContentDocumentId: this.resumeContentDocumentId
        })
            .then(() => {
                this.message = 'You have successfully applied!';
                this.error = undefined;

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: this.message,
                        variant: 'success'
                    })
                );
            })
            .catch(e => {
                this.error = e.body?.message || 'Failed to apply.';
                this.message = undefined;

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: this.error,
                        variant: 'error'
                    })
                );
            });
    }
}