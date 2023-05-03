# azure_batch
This repo is designed to enable and support the capability and usage of Azure Batch.


Based on some of the newer updates I wanted to address the exciting changes in Azure Batch.  The key updates center around removing the need for Public IP addresses for both the jobs and pools. I wanted to highlight leveraging both Azure Private Endpoints (for both the Batch Account and Node Management endpoints) as well as securing access.  See [here](https://learn.microsoft.com/en-us/azure/batch/private-connectivity) for more information.

Like this: ![Azure Batch Architecture using Private Endpoints}(../blob/31da5796c985d2509ecfcb88f9fc9170b21a06db/media/Azure%20Batch%20Private%20Endpoint%20Design.png)

In order to make use of the Azure Private Endpoints, ensure that the access point is from an approved location.  So in this example I am using my Windows workstation that has access to both the Storage Account and Batch Account.

Here are the two files that I have created:
1. Create_Batch_Pool.ps1 - a powershell script that is a documented approach to implementing an Azure Batch Pool.  This fully documented script includes information on deploying the [Simplified Compute Node Communication](https://learn.microsoft.com/en-us/azure/batch/simplified-compute-node-communication).

2. Deploy_Batch_job.ps1 - this likely a more common use case (because Pool deployments like the Batch account itself are often deployed via the portal or using a declarative language like Bicep), if you need to deploy tasks into an Azure Batch Pool.

Please submit any question or issues as you perform your testing.
