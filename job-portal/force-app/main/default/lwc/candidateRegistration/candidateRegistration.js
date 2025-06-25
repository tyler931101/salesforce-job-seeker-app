import { LightningElement, track } from 'lwc';
import registerCandidate from '@salesforce/apex/CandidateController.registerCandidate';
import { NavigationMixin } from 'lightning/navigation';

export default class CandidateRegistration extends NavigationMixin(LightningElement) {
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track phone = '';
    @track password = '';
    @track confirmPassword = '';
    @track errorMessage = '';
    @track successMessage = '';

    handleInputChange(event) {
        const { name, value } = event.target;
        this[name] = value;
    }

    handleRegister() {
        this.errorMessage = '';
        this.successMessage = '';

        if (!this.firstName || !this.lastName || !this.email || !this.phone || !this.password || !this.confirmPassword) {
            this.errorMessage = 'All fields are required.';
            return;
        }

        if (this.password !== this.confirmPassword) {
            this.errorMessage = 'Password and Confirm Password do not match.';
            return;
        }

        registerCandidate({
            firstName: this.firstName,
            lastName: this.lastName,
            phone: this.phone,
            email: this.email,
            password: this.password
        })
        .then(() => {
            this.successMessage = 'Registration successful! Redirecting to login...';

            // Clear form
            this.firstName = '';
            this.lastName = '';
            this.email = '';
            this.phone = '';
            this.password = '';
            this.confirmPassword = '';

            // Redirect to login page (use your exact login page API name)
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'Candidate_Login__c'
                }
            });
        })
        .catch(error => {
            console.error('Registration error', JSON.stringify(error));
            this.errorMessage = 'Registration failed. ' + (error.body?.message || 'Please try again.');
        });
    }
}