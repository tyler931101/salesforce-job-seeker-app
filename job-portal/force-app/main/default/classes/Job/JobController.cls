public with sharing class JobController {

    @AuraEnabled(cacheable=true)
    public static Boolean isRecruiter() {
        List<Candidate__c> candidates = [
            SELECT Id, Role__c
            FROM Candidate__c
            WHERE Email__c = :UserInfo.getUserEmail()
            LIMIT 1
        ];

        return !candidates.isEmpty() && candidates[0].Role__c == 'Recruiter';
    }
    //recruiter create a new job
    @AuraEnabled
    public static void createJob(
        String title,
        String description,
        String type,
        Decimal salary,
        String status,
        String location,
        Date datePosted
    ) {
        // Get current user's candidate record
        List<Candidate__c> candidates = [
            SELECT Id, Role__c, Email__c
            FROM Candidate__c
            WHERE Email__c = :UserInfo.getUserEmail()
            LIMIT 1
        ];

        if (candidates.isEmpty() || candidates[0].Role__c != 'Recruiter') {
            throw new AuraHandledException('Only recruiters can create jobs.');
        }

        String recruiterEmail = candidates[0].Email__c;

        Job__c job = new Job__c(
            Title__c = title,
            Description__c = description,
            Type__c = type,
            Salary__c = salary,
            Status__c = status,
            Location__c = location,
            Date_Posted__c = datePosted,
            Recruiter__c = recruiterEmail // Text field storing email
        );

        insert job;
    }
    //get all open jobs for candidates
    @AuraEnabled(cacheable=true)
    public static List<Job__c> candidateGetJobs() {
        return [
            SELECT Id, Title__c, Description__c, Type__c, Salary__c, Location__c, Date_Posted__c
            FROM Job__c
            WHERE Status__c = 'Open'
            ORDER BY Date_Posted__c DESC
        ];
    }

    
    //get apply job
    @AuraEnabled(cacheable=true)
    public static Job__c getJobById(String jobId) {
        return [
            SELECT Id, Title__c, Description__c, Type__c, Salary__c, Location__c, Date_Posted__c
            FROM Job__c
            WHERE Id = :jobId
            LIMIT 1
        ];
    }
    
    //apply
    @AuraEnabled
    public static Id applyForJob(String jobId, String candidateEmail, String firstName, String lastName, String coverLetter, String resumeContentDocumentId) {
        // Fetch candidate by email
        Candidate__c candidate = [
            SELECT Id FROM Candidate__c WHERE Email__c = :candidateEmail LIMIT 1
        ];

        // Check for duplicates
        List<Application__c> existing = [
            SELECT Id
            FROM Application__c
            WHERE Candidate__c = :candidate.Id AND Job__c = :jobId
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            throw new AuraHandledException('You have already applied for this job.');
        }

        // Get job info with recruiter email
        Job__c job = [
            SELECT Id, Title__c, Recruiter__c
            FROM Job__c
            WHERE Id = :jobId
            LIMIT 1
        ];

        if (String.isBlank(job.Recruiter__c)) {
            throw new AuraHandledException('Recruiter email is missing.');
        }

        // Update candidate fields
        candidate.First_Name__c = firstName;
        candidate.Last_Name__c = lastName;
        candidate.Cover_Letter__c = coverLetter;

        if (!String.isBlank(resumeContentDocumentId)) {
            // Save full download link in Resume__c (URL field)
                String resumeUrl = URL.getOrgDomainUrl().toExternalForm() +
                '/sfc/servlet.shepherd/document/download/' + resumeContentDocumentId;

            candidate.Resume__c = resumeUrl;

            // Link file to candidate record
            insert new ContentDocumentLink(
                ContentDocumentId = resumeContentDocumentId,
                LinkedEntityId = candidate.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );

        }
        update candidate;

        // Create new application
        Application__c app = new Application__c(
            Job__c = jobId,
            Candidate__c = candidate.Id,
            Status__c = 'Applied',
            Submission_Date__c = Date.today()
        );

        insert app;

        // Send email to recruiter
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { job.Recruiter__c });
        mail.setSubject('New Job Application for "' + job.Title__c + '"');
        mail.setPlainTextBody(
            'A new application has been submitted for the job "' + job.Title__c + '".\n\n' +
            '\n\nCandidate: ' + firstName + ' ' + lastName +
            '\nEmail: ' + candidateEmail +
            // '\nPhone: ' + phone +
            // '\nAddress: ' + address +
            '\n\nCover Letter:\n' + coverLetter
        );
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

        return app.Id;
    }

}