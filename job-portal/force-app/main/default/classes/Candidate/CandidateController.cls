public with sharing class CandidateController {

    @AuraEnabled
    public static void registerCandidate(String firstName, String lastName, String email, String password, String phone) {
        System.debug('--- Registering Candidate ---');
        System.debug('First: ' + firstName);
        System.debug('Last: ' + lastName);
        System.debug('Email: ' + email);

        // Check if email already exists
        List<Candidate__c> existing = [
            SELECT Id FROM Candidate__c WHERE Email__c = :email LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new AuraHandledException('Email already registered.');
        }

        // Generate 16-byte salt
        Blob saltBlob = Crypto.generateAesKey(128);

        // Convert salt to hex string
        String saltHex = EncodingUtil.convertToHex(saltBlob);

        // Concatenate password + salt hex string
        String combinedString = password + saltHex;

        // Convert combined string to Blob
        Blob combinedBlob = Blob.valueOf(combinedString);

        // Hash combined blob using SHA-256
        Blob hashedBlob = Crypto.generateDigest('SHA-256', combinedBlob);

        // Convert hash to hex string for storage
        String hashedPassword = EncodingUtil.convertToHex(hashedBlob);

        Candidate__c candidate = new Candidate__c(
            First_Name__c = firstName,
            Last_Name__c = lastName,
            Email__c = email,
            Password__c = hashedPassword,
            Salt__c = saltHex,
            Phone__c = phone, 
            Role__c = 'Candidate'
        );

        try {
            insert candidate;
            System.debug('--- Candidate inserted with ID: ' + candidate.Id);
        } catch (Exception e) {
            throw new AuraHandledException('Registration failed: ' + e.getMessage());
        }
    }

    // Verify password by hashing input + stored salt and comparing to stored hash
    @AuraEnabled
    public static Boolean verifyLogin(String email, String submittedPassword) {
        try {
            Candidate__c candidate = [
                SELECT Password__c, Salt__c
                FROM Candidate__c
                WHERE Email__c = :email
                LIMIT 1
            ];

            if (candidate == null) {
                return false;
            }

            String storedHash = candidate.Password__c;
            String storedSalt = candidate.Salt__c;

            // Recreate hash from submitted password and stored salt
            String combinedString = submittedPassword + storedSalt;
            Blob combinedBlob = Blob.valueOf(combinedString);
            Blob hashedBlob = Crypto.generateDigest('SHA-256', combinedBlob);
            String hashedInput = EncodingUtil.convertToHex(hashedBlob);

            return hashedInput == storedHash;
        } catch (Exception e) {
            // Handle no candidate found or query exception
            return false;
        }
    }
}