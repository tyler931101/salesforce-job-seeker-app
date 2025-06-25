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
        String q = 'SELECT Id, Status__c, Submission_Date__c, Interview_Date__c, ' +
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
                a.Interview_Date__c,
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
        @AuraEnabled public Datetime interviewDate;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateFirstName;
        @AuraEnabled public String candidateLastName;
        @AuraEnabled public String candidateEmail;
        @AuraEnabled public String resumeUrl;

        public ApplicationWrapper(Id appId, String st, Datetime subDate, Datetime intDate, Id cid, String fn, String ln, String email, String resume) {
            applicationId = appId;
            status = st;
            submissionDate = subDate;
            interviewDate = intDate;
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

    @AuraEnabled
    public static void scheduleInterview(Id applicationId, Datetime interviewDateTime) {
        Application__c app = [SELECT Id FROM Application__c WHERE Id = :applicationId LIMIT 1];
        app.Interview_Date__c = interviewDateTime;
        update app;
    }

    // New method to send Google Calendar link invite email
    @AuraEnabled
    public static void sendInterviewGoogleCalendarLinkEmail(Id applicationId, Datetime interviewDateTime) {
        Application__c app = [
            SELECT Id, Candidate__r.Email__c, Candidate__r.First_Name__c, Candidate__r.Last_Name__c, Job__r.Title__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        if (app == null || String.isBlank(app.Candidate__r.Email__c)) {
            throw new AuraHandledException('Candidate email not found.');
        }

        String candidateEmail = app.Candidate__r.Email__c;
        String candidateName = app.Candidate__r.First_Name__c + ' ' + app.Candidate__r.Last_Name__c;
        String jobTitle = app.Job__r.Title__c;

        Datetime endDateTime = interviewDateTime.addHours(1);

        String dtStart = interviewDateTime.formatGMT('yyyyMMdd\'T\'HHmmss\'Z\'');
        String dtEnd = endDateTime.formatGMT('yyyyMMdd\'T\'HHmmss\'Z\'');

        String eventTitle = EncodingUtil.urlEncode('Interview for ' + jobTitle, 'UTF-8');
        String eventDetails = EncodingUtil.urlEncode('Interview scheduled with ' + candidateName, 'UTF-8');
        String location = EncodingUtil.urlEncode('Your Company Location', 'UTF-8');

        String calendarUrl = 'https://calendar.google.com/calendar/render?action=TEMPLATE'
            + '&text=' + eventTitle
            + '&dates=' + dtStart + '/' + dtEnd
            + '&details=' + eventDetails
            + '&location=' + location
            + '&add=' + EncodingUtil.urlEncode(candidateEmail + ',' + UserInfo.getUserEmail(), 'UTF-8');

        String emailBody = 'Dear ' + candidateName + ',\n\n' +
            'Your interview has been scheduled on ' + interviewDateTime.format('MMMM d, yyyy h:mm a') + '.\n\n' +
            'Please add this interview to your Google Calendar by clicking the link below:\n' +
            calendarUrl + '\n\n' +
            'Best regards,\nRecruitment Team';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { candidateEmail });
        mail.setSubject('Interview Scheduled for ' + jobTitle);
        mail.setPlainTextBody(emailBody);

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}