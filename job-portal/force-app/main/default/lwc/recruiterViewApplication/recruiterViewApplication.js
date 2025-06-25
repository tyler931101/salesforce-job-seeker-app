import { LightningElement, track, wire } from 'lwc';
import getRecruiterJobs from '@salesforce/apex/ApplicationController.getRecruiterJobs';
import getApplicationsForJob from '@salesforce/apex/ApplicationController.getApplicationsForJob';
import updateApplicationStatus from '@salesforce/apex/ApplicationController.updateApplicationStatus';
import sendEmailToCandidate from '@salesforce/apex/ApplicationController.sendEmailToCandidate';

import scheduleInterview from '@salesforce/apex/ApplicationController.scheduleInterview';
import sendInterviewGoogleCalendarLinkEmail from '@salesforce/apex/ApplicationController.sendInterviewGoogleCalendarLinkEmail';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class RecruiterViewApplication extends LightningElement {
    @track jobs = [];
    @track selectedJobId = '';
    @track statusFilter = '';
    @track applications = [];
    @track selectedApplication = null;
    @track errorMessage = '';

    @track emailSubject = '';
    @track emailBody = '';

    @track interviewDateTime = '';

    @wire(getRecruiterJobs)
    wiredJobs({ data, error }) {
        if (data) {
            this.jobs = data;
            if (!this.selectedJobId && data.length > 0) {
                this.selectedJobId = data[0].Id;
                this.loadApplications();
            }
        } else if (error) {
            this.showToast('Error loading jobs', error?.body?.message || error.message, 'error');
        }
    }

    get statusOptions() {
        return [
            { label: 'All', value: '' },
            { label: 'Applied', value: 'Applied' },
            { label: 'Interviewing', value: 'Interviewing' },
            { label: 'Hired', value: 'Hired' },
            { label: 'Rejected', value: 'Rejected' }
        ];
    }

    handleJobSelect(event) {
        const jobId = event.currentTarget.dataset.id;
        this.selectedJobId = jobId;
        this.selectedApplication = null;
        this.loadApplications();
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.target.value;
        this.selectedApplication = null;
        this.loadApplications();
    }

    loadApplications() {
        getApplicationsForJob({ jobId: this.selectedJobId, statusFilter: this.statusFilter })
            .then(result => {
                this.applications = result;
                this.errorMessage = '';
            })
            .catch(error => {
                this.errorMessage = 'Error loading applications';
                this.showToast('Error loading applications', error?.body?.message || error.message, 'error');
                console.error('loadApplications error:', error);
            });
    }

    handleSelectApplication(event) {
        const applicationId = String(event.currentTarget.dataset.id);
        this.selectedApplication = this.applications.find(app => String(app.applicationId) === applicationId);
        this.emailSubject = '';
        this.emailBody = '';
        this.interviewDateTime = this.selectedApplication?.interviewDate ? this.selectedApplication.interviewDate : '';
    }

    handleStatusUpdate(newStatus) {
        if (!this.selectedApplication) return;
        updateApplicationStatus({ applicationId: this.selectedApplication.applicationId, newStatus })
            .then(() => {
                this.showToast('Success', `Status updated to ${newStatus}`, 'success');
                this.loadApplications();
                this.selectedApplication = null;
            })
            .catch(error => {
                this.showToast('Error updating status', error?.body?.message || error.message, 'error');
                console.error('Status update error:', error);
            });
    }

    handleEmailInputChange(event) {
        const { name, value } = event.target;
        this[name] = value;
    }

    handleMarkInterviewing() {
        this.handleStatusUpdate('Interviewing');
    }
    handleMarkHired() {
        this.handleStatusUpdate('Hired');
    }
    handleMarkRejected() {
        this.handleStatusUpdate('Rejected');
    }

    handleSendEmail() {
        if (!this.selectedApplication) return;
        if (!this.emailSubject || !this.emailBody) {
            this.showToast('Error', 'Subject and body are required', 'error');
            return;
        }

        sendEmailToCandidate({
            applicationId: this.selectedApplication.applicationId,
            subject: this.emailSubject,
            body: this.emailBody
        })
            .then(() => {
                this.showToast('Success', 'Email sent to candidate', 'success');
                this.emailSubject = '';
                this.emailBody = '';
            })
            .catch(error => {
                this.showToast('Error sending email', error?.body?.message || error.message, 'error');
                console.error('Email send error:', error);
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        this[name] = value;
    }
    
    handleScheduleInterview() {
        if (!this.selectedApplication || !this.interviewDateTime) {
            this.showToast('Error', 'Please select a candidate and set interview date/time.', 'error');
            return;
        }

        scheduleInterview({
            applicationId: this.selectedApplication.applicationId,
            interviewDateTime: this.interviewDateTime
        })
        .then(() => {
            return sendInterviewGoogleCalendarLinkEmail({
                applicationId: this.selectedApplication.applicationId,
                interviewDateTime: this.interviewDateTime
            });
        })
        .then(() => {
            this.showToast('Success', 'Interview scheduled and Google Calendar invite sent.', 'success');
            this.interviewDateTime = '';
            this.loadApplications();
            this.selectedApplication = null;
        })
        .catch(error => {
            this.showToast('Error', error?.body?.message || error.message, 'error');
            console.error(error);
        });
    }
}