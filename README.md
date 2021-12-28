# tomorr-terraform
Setup for tomorr on AWS

## Steps to complete before creating the infrastructure

- Create a new *Verified identity for SES* and new *SMTP credentials*
- Create the *CodePipeline*
- Create a new bucket to hold the *application.yml* for production
- Create a new AMI from the scripts of `tomorr-ami` repository.

## Steps to complete after creating the infrastructure

- Get the `outputs` from `terraform` and add them to the *application.yml* file, and upload them to the bucket that holds the production properties
- Run the schema on the created database
- Trigger the codepipeline to deploy the application on the newly created instances

_Note_: Most of the steps above will be automated in the future