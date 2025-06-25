public with sharing class ApplicationController {
    @AuraEnabled(cacheable=true)
    public static List<Job__c> getRecruiterJobs() {
        String email = UserInfo.getUserEmail();
        return [
            SELECT Id, Title__c
            FROM Job__c
            WHERE Recruiter__c = :email
            ORDER BY Date_Posted__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ApplicationWrapper> getApplicationsForJob(Id jobId, String statusFilter) {
        String q = 'SELECT Id, Status__c, Submission_Date__c, ' +
                   'Candidate__r.Id, Candidate__r.First_Name__c, Candidate__r.Last_Name__c, ' +
                   'Candidate__r.Email__c, Candidate__r.Resume__c ' +
                   'FROM Application__c WHERE Job__c = :jobId';

        if (String.isNotBlank(statusFilter)) {
            q += ' AND Status__c = :statusFilter';
        }
        q += ' ORDER BY Submission_Date__c DESC';

        List<Application__c> apps = Database.query(q);
        List<ApplicationWrapper> results = new List<ApplicationWrapper>();
        for (Application__c a : apps) {
            results.add(new ApplicationWrapper(
                a.Id,
                a.Status__c,
                a.Submission_Date__c,
                a.Candidate__r.Id,
                a.Candidate__r.First_Name__c,
                a.Candidate__r.Last_Name__c,
                a.Candidate__r.Email__c,
                a.Candidate__r.Resume__c
            ));
        }
        return results;
    }

    public class ApplicationWrapper {
        @AuraEnabled public Id applicationId;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime submissionDate;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateFirstName;
        @AuraEnabled public String candidateLastName;
        @AuraEnabled public String candidateEmail;
        @AuraEnabled public String resumeUrl;

        public ApplicationWrapper(Id appId, String st, Datetime date, Id cid, String fn, String ln, String email, String resume) {
            applicationId = appId;
            status = st;
            submissionDate = date;
            candidateId = cid;
            candidateFirstName = fn;
            candidateLastName = ln;
            candidateEmail = email;
            resumeUrl = resume;
        }
    }

    @AuraEnabled
    public static void updateApplicationStatus(Id applicationId, String newStatus) {
        Application__c app = [SELECT Id FROM Application__c WHERE Id = :applicationId LIMIT 1];
        app.Status__c = newStatus;
        update app;
    }

    @AuraEnabled
    public static void sendEmailToCandidate(Id applicationId, String subject, String body) {
        Application__c app = [
            SELECT Candidate__r.Email__c, Job__r.Title__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { app.Candidate__r.Email__c });
        email.setSubject(subject);
        email.setPlainTextBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}