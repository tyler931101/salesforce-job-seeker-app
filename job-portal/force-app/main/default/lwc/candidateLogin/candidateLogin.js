import { LightningElement, track } from 'lwc';
import verifyLogin from '@salesforce/apex/CandidateController.verifyLogin';
import { NavigationMixin } from 'lightning/navigation';

export default class CandidateLogin extends NavigationMixin(LightningElement) {
    @track email = '';
    @track password = '';
    @track errorMessage = '';
    @track successMessage = '';

    handleInputChange(event) {
        const { name, value } = event.target;
        this[name] = value;
    }

    handleLogin() {
        this.errorMessage = '';
        this.successMessage = '';

        if (!this.email || !this.password) {
            this.errorMessage = 'Please enter email and password.';
            return;
        }

        verifyLogin({ email: this.email, submittedPassword: this.password })
            .then(isValid => {
                if (isValid) {
                    this.successMessage = 'Login successful! Redirecting...';

                    // Save login state in localStorage
                    window.localStorage.setItem('candidateEmail', this.email);

                    // Redirect to a Lightning page or community page named 'candidate_home'
                    this[NavigationMixin.Navigate]({
                        type: 'comm__namedPage',
                        attributes: {
                            pageName: 'candidateHome' // Change to your actual page API name
                        }
                    });
                } else {
                    this.errorMessage = 'Invalid email or password.';
                }
            })
            .catch(error => {
                this.errorMessage = 'Login failed. ' + (error.body?.message || 'Please try again.');
            });
    }
}