import { LightningElement, track } from 'lwc';
import isRecruiter from '@salesforce/apex/JobController.isRecruiter';
import createJob from '@salesforce/apex/JobController.createJob';

export default class JobCreation extends LightningElement {
    @track title = '';
    @track description = '';
    @track type = '';
    @track salary = null;
    @track status = '';
    @track location = '';
    @track datePosted = '';

    @track errorMessage = '';
    @track successMessage = '';
    @track isRecruiter = false;

    typeOptions = [
        { label: 'Full-time', value: 'Full-time' },
        { label: 'Part-time', value: 'Part-time' },
        { label: 'Contract', value: 'Contract' },
        { label: 'Internship', value: 'Internship' }
    ];

    statusOptions = [
        { label: 'Open', value: 'Open' },
        { label: 'Closed', value: 'Closed' },
        { label: 'Paused', value: 'Paused' }
    ];

    connectedCallback() {
        isRecruiter()
            .then(result => {
                this.isRecruiter = result;
            })
            .catch(error => {
                this.errorMessage = 'Error checking permissions.';
                console.error(error);
            });
    }

    handleChange(event) {
        const { name, value } = event.target;

        if (name === 'salary') {
            this.salary = value ? parseFloat(value) : null;
        } else {
            this[name] = value;
        }
    }

    handleCreateJob() {
        this.errorMessage = '';
        this.successMessage = '';

        if (!this.title || !this.description || !this.type || this.salary === null || !this.status || !this.location || !this.datePosted) {
            this.errorMessage = 'Please fill all required fields.';
            return;
        }

        createJob({
            title: this.title,
            description: this.description,
            type: this.type,
            salary: this.salary,
            status: this.status,
            location: this.location,
            datePosted: this.datePosted
        })
        .then(() => {
            this.successMessage = 'Job created successfully!';
            this.title = '';
            this.description = '';
            this.type = '';
            this.salary = null;
            this.status = '';
            this.location = '';
            this.datePosted = '';
        })
        .catch(error => {
            this.errorMessage = error.body?.message || 'Error creating job.';
            console.error(error);
        });
    }
}