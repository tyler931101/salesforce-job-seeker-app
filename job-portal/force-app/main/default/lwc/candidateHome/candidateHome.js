import { LightningElement, wire, track } from 'lwc';
import candidateGetJobs from '@salesforce/apex/JobController.candidateGetJobs';
import { NavigationMixin } from 'lightning/navigation';

export default class CandidateHome extends NavigationMixin(LightningElement) {
    @track candidateEmail = '';
    @track jobs = [];
    @track selectedJob = null;
    @track error;
    @track isLoading = true;

    connectedCallback() {
        this.candidateEmail = window.localStorage.getItem('candidateEmail') || 'Guest';
    }

    handleLogout() {
        window.localStorage.removeItem('candidateEmail');
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'candidateLogin'
            }
        });
    }

    @wire(candidateGetJobs)
    wiredJobs({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.jobs = data;
            if (data.length > 0) {
                this.selectedJob = data[0]; // default select first job
            }
        } else if (error) {
            this.error = 'Failed to load jobs.';
            console.error(error);
        }
    }

    handleJobClick(event) {
        const jobId = event.currentTarget.dataset.id;
        this.selectedJob = this.jobs.find(job => job.Id === jobId);
    }

    handleApply() {
        const jobId = this.selectedJob?.Id;
        if (!jobId) return;
    
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'apply-job-page' // must match the URL slug, not the API name
            },
            state: {
                c__jobId: jobId
            }
        });
    }
}