# tomorr-terraform
Setup for tomorr on AWS

## Optional to complete before creating the infrastructure

- If you plan on using AWS SES for the application email service, create a new *Verified identity for SES* and new *SMTP credentials*, otherwise create *SMTP credentials* from any other service you plan on use.
- Create IAM users that will have the least amount of privileges needed, for the CI/CD pipeline you plan on using.

## Steps to complete after creating the infrastructure

- Get the needed configuration data from the created resources (RDS endpoint, MQ Broker endpoint, Elasticache cluster endpoint, etc) and add them in a `tomorr-app.env` file as environment variables. Include in this file other configurations that can be done using environment variables as well (_Please check [here](https://github.com/kushtrimh/tomorr#environment-variables) for all the accepted environment variables_). Once everything is configured in the file, upload the file to the S3 bucket created for holding the environment data, which will be later used by ECS on deployment. 
- Run the schema on the created database
- Trigger the CI/CD pipeline to deploy the application

_Note_: Most of the steps above will be automated in the future