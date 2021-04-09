%HPC Pack Burst to Azure Batch

> *Documented by*
>
> **Matthew W. Perry** and **Eduardo Gomez**
>
> Microsoft Cloud Solution Architects
>
> *Purpose:* This document is intended to provide the steps needed to
> connect an on-premises HPC Pack implementation to burst into Azure
> while still supporting the existing compute pools. It is not intended
> to provide step by step instructions and comes without any warranty or
> guarantee. Please see the Microsoft documentation for more
> information.

# Architecture Design

![Visio Diagram depicting HPC Pack on Premise and Azure
Batch](media/image3.png)

# Requirements

> Based our client example. Some common Technical and Business
> Requirements would be:

-   Enabling a low barrier and cost-effective approach to deploy Batch
    jobs at scale to cloud

-   Support Bursting from existing infrastructure with a least
    disruptive approach (i.e. continue to leverage HPC Pack on-premises)

-   Keep costs contained and retain the service level (SLA) as is
    provided on-premises, where the compute nodes can be semi-disposable

-   Using HPC Pack 2019

-   Files used for Input can be shared with the Azure Files, but the
    primary copy must be on premise (this can be replicated via script
    or manually)

-   Need to be able to write back to the on-premises Database

# Highlevel Steps

[1. Ensure network connectivity between the HPC Pack 2019 and Azure
subscription
](#ensure-network-connectivity-between-the-hpc-pack-2019-and-azure-subscription)

[2. Setup the Azure Batch Account and Collect Connection Information
](#setup-the-azure-batch-account-and-collect-connection-information)

[3. Create the Azure Storage account for Azure Files
](#create-the-azure-storage-account-for-azure-files)

[4. Set the Azure Batch Configuration in HPC Pack
](#set-the-azure-batch-configuration-in-hpc-pack)

[5. HPC Pack create a new Node Template for Azure Batch
](#hpc-pack-create-a-new-node-template-for-azure-batch)

[6. Deploy Pool into the Azure Batch Subnet and Storage Mounting
](#deploy-pool-into-the-azure-batch-subnet-and-storage-mounting)

## Ensure network connectivity between the HPC Pack 2019 and Azure subscription

*Assumption:* Azure VPN is setup and configured

To test connectivity, we need to ensure that there is routing and no
Firewalls or Network Security Groups blocking:

-   Communication between the HPC Pack server to the Azure Batch
    environment

-   Connectivity from the Azure Batch subnet to the database that
    captures the output

-   Manage Storage account Firewall access to/from the Azure Batch
    subnet, and to permit a scripted or applet (as in the Azure Storage
    Explorer) to replicate the data store for data input

*Resources:*

[Using Powershell to Test Network connections:]{.ul}
https://docs.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection?view=windowsserver2019-ps

[Azure Network Watcher]{.ul}:
<https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-connectivity-portal>

[Azure Files Network Considerations]{.ul}:
https://docs.microsoft.com/en-us/azure/storage/files/storage-files-networking-overview

[Azure Storage Explorer:]{.ul}
https://azure.microsoft.com/en-us/features/storage-explorer/

[HPC Pack Communication to Azure Batch]{.ul}:
https://docs.microsoft.com/en-us/powershell/high-performance-computing/requirements-to-add-azure-nodes-with-microsoft-hpc-pack?view=hpc19-ps\#BKMK_ports

## Setup the Azure Batch Account and Collect Connection Information

Source: for this walk through is pulled from the Microsoft source
information located
[here](https://docs.microsoft.com/en-us/powershell/high-performance-computing/burst-to-azure-batch-with-microsoft-hpc-pack?view=hpc19-ps).

### Setting up the Azure Batch environment 

This can be completed through the portal, Azure Resource Manager
Templates, via CLI or Scripting. An Azure Application registration
should be setup to perform the needed Authentication for HPC into the
Azure Batch compute nodes.

For setting up the Batch environment using an example Azure Resource
Manager templates to automatically deploy the environment, see [here for
more details](https://github.com/azuregomez/AzBatch) and configuration
variables required. Alternatively, the Batch environment can be deployed
using the Azure portal. See
[here](https://azure.microsoft.com/documentation/articles/batch-account-create-portal/)
for more information on deploying the Azure Batch Account.

During the Azure Batch deployment be sure to document the following
information:

> Batch account name
>
> Batch account URL
>
> Batch account key

When setting up the Batch environment there are three options for
configuring authentication as depicted in the graphic below:![Text
Description automatically
generated](media/image4.png){width="6.153437226596675in"
height="2.286457786526684in"}

Source:
<https://docs.microsoft.com/en-us/powershell/high-performance-computing/burst-to-azure-batch-with-microsoft-hpc-pack?view=hpc19-ps#BKMK_Account>

The approach we have taken (albeit there is a requirement to connect to
a specific VNet in order to communicate back to the on-premise database
for reporting) is the second option. Although it isn't obvious from the
documentation this is creating an Azure AD Application registration and
providing that registration the appropriate API access. With this
solution we can leverage Custom IaaS images, Low Priority VMs, as well
as deploy the Batch compute nodes into our pre-defined Subnet.

### Creating the Application Registration

This section walks through the process of creating an Azure Application
Registration and the approach to enable authentication. As this is being
created capture both the application ID for the App registration, and
the Secret information for use when setting up the HPC Pack -- Azure
Batch Configuration.

In Azure Active Directory -- under App Registrations, select *New
Registration*.

![Graphical user interface, text, application Description automatically
generated](media/image5.png){width="6.010416666666667in"
height="2.1470548993875767in"}

Next ensure that the registration has been granted, create a new Client
Secret, and store the Client ID and Secret information. This will be
required for setting up Azure Deployment information and Azure Batch
Configuration in HPC Pack.

![Graphical user interface, text Description automatically
generated](media/image6.png){width="6.199645669291338in"
height="3.7760411198600177in"}

Next grant the App registration API Permissions for Azure Batch, and
Microsoft Graph:

![Graphical user interface, text, application, email Description
automatically generated](media/image7.png){width="6.137211286089239in"
height="2.7395833333333335in"}

Source:
<https://docs.microsoft.com/en-us/azure/batch/batch-aad-auth#use-integrated-authentication>

Lastly, add the service principal to the scope where the application
will be created. A good rule of thumb would be to enable this newly
created Service Principal at the Resource Group where all of the project
resources exist (in order to maintain the same life cycle), and ensure
that the Services principal is granted *Contributor* (or it can be
*Reader* but would recommend testing after setup). For a step by step,
see
[here](https://docs.microsoft.com/en-us/azure/batch/batch-aad-auth#assign-azure-rbac-to-your-application).

*Resources:*

*[Creating an Azure Batch Account]{.ul}:*
https://azure.microsoft.com/documentation/articles/batch-account-create-portal/

[HPC Pack Bursting to Batch]{.ul}:
https://docs.microsoft.com/en-us/powershell/high-performance-computing/burst-to-azure-batch-with-microsoft-hpc-pack?view=hpc19-ps

[Azure Batch Authentication Methods]{.ul}:
https://docs.microsoft.com/en-us/azure/batch/batch-aad-auth\#use-integrated-authentication

## Create the Azure Storage account for Azure Files

Requirement: For our use case Azure Files would meet the requirement.
The performance of the Azure Files hasn't been assessed but for
mitigating any potential risk, it is highly recommended to set up the
Azure Files with a Premium File Share (information regarding performance
of Azure Files --
[here](https://docs.microsoft.com/en-us/azure/storage/files/storage-files-scale-targets#azure-file-share-scale-targets))

### Setting up the Azure Storage Account

Deploying the Azure Files to a storage account can be performed via the
Azure portal, Azure Resource Manager, CLI or Script. This approach will
point to the documentation on deploying through the Azure portal --
[here](https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-use-files-portal).

The following information will be needed to setup the account:

Storage redundancy to support the SLA that is required, likely this will
be just *Locally Redundant Storage*, because the application will have a
copy of the data on premise.

Region -- again this needs to map to the same as the Batch Account

Firewall Configuration -- suggestion here would be to keep this open and
only until the environment is fully setup (later this can be locked down
to only permit traffic with the Azure Batch subnet and the file
replication source.

Document the following Azure File attributes for creating the Azure
Batch Configuration:

> Account Name
>
> Account Key
>
> Azure File Url

*Resources:*

[Azure File Performance]{.ul}:
<https://docs.microsoft.com/en-us/azure/storage/files/storage-files-scale-targets>

[Optimize Azure File Configuration with SMB Multichannel]{.ul}:
https://docs.microsoft.com/en-us/azure/storage/files/storage-files-smb-multichannel-performance

[Deploy Azure Files via the portal]{.ul}:
https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-use-files-portal

## Set the Azure Batch Configuration in HPC Pack

On the on-premise Windows HPC head node open the HPC Pack 2019 Cluster
Manager. From here we can setup and configure the connection to both
Azure and the Batch account.

Select the Configuration and under the *Configuration* choose the
"*Deployment To-do List*". This is where we select the "Set Azure Batch
Configuration" options. Next add in the details that we captured
earlier.

![Screenshot of the HPC Pack 2019 Cluster Mgr
Configuration](media/image8.png){width="5.492832458442694in"
height="3.71875in"}

In the "Set Azure Batch Configuration" form set the following values:

![Image of the Azure Batch Configuration
Form](media/image9.png){width="3.9531255468066493in"
height="2.691053149606299in"}

*Batch AAD Instance* -- this is the primary service endpoint for global
Azure Cloud Azure Authentication (AAD). This will typically be the same
as the Batch AAD Tenant ID with the https://login.microsoftonline.com/
prepending it.

*Batch AAD Tenant Id* -- as stated for the Batch ADD Instance, is likely
the same, but is only the GUID for the tenant. This can be gleaned from
the Azure portal, by selecting Azure Active Directory in the Overview
blade. This will contain the Tenant information and GUID, or using the
CLI after login will display the Tenant ID (az login).

*Batch AAD ClientApp Id* -- pull the client app ID from step 2 where the
App Registration was created

*Batch AAD ClientApp Key* -- take the key that was generated in step 2
when creating the secret for the App Registration (service principal).

*Resources:*

[Configuring Azure AD for Batch Authentication]{.ul}:
https://docs.microsoft.com/en-us/powershell/high-performance-computing/burst-to-azure-batch-with-microsoft-hpc-pack?view=hpc19-ps\#to-configure-azure-ad-for-batch-authentication-and-obtain-batch-aad-info

## HPC Pack create a new Node Template for Azure Batch

Source: [Create an Azure Batch Pool
Template](https://docs.microsoft.com/en-us/powershell/high-performance-computing/burst-to-azure-batch-with-microsoft-hpc-pack?view=hpc19-ps#BKMK_Templ)

In the HPC 2019 Cluster Manager, under *Configuration* in the Navigation
pane select "*Node Templates*" and "New" under Actions

Choose "*Azure Batch Pool Template"* and "*Next*", and then enter
Template Name and select "*Next*" again.

For providing the *Provide Azure Batch Account Information*, add the
*Azure Batch account name*, *Azure Batch Account URL*, and *Azure
Storage Connection String*, from step 1. Leave the Account Key option
Blank (we need to ensure that uses Azure AD).

![HPC Cluster Admin Node Template for Batch Template screen
print](media/image10.png){width="6.5in" height="3.2402777777777776in"}

Next select the *Autoscale Configuration* options -- often the Default
option meets the requirements but configuring the formula details for
Autoscale can be found
[here](https://docs.microsoft.com/en-us/azure/batch/batch-automatic-scaling).

![Screen print from the HPC cluster admin Autoscale Configuration
options](media/image11.png){width="5.817708880139983in"
height="2.7820581802274718in"}

For the next two sections, add RDP / SSH connection information as
required, as well as specifying a Startup Script command line as needed.

*Resources:*

[Create an Azure Batch Pool Template]{.ul}:
https://docs.microsoft.com/en-us/powershell/high-performance-computing/burst-to-azure-batch-with-microsoft-hpc-pack?view=hpc19-ps\#BKMK_Templ

[Azure Batch Automatically scale compute nodes]{.ul}:
https://docs.microsoft.com/en-us/azure/batch/batch-automatic-scaling

## Deploy Pool into the Azure Batch Subnet and Storage Mounting

Source: [Configure Add an Azure Batch
Pool](https://docs.microsoft.com/en-us/powershell/high-performance-computing/burst-to-azure-batch-with-microsoft-hpc-pack?view=hpc19-ps#BKMK_Add)

Following deploying the Node template, the instructions from the source
document reference above are accurate, but certain details need to be
called out.

![Azure Batch Pool Configuration
view](media/image12.png){width="5.854983595800525in"
height="4.469373359580053in"}

After selecting the *Add Azure Batch Pool*:

Ensure that the newly created template is selected and choose for the
*ImageType* either the *IaaSMarketPlace*, or *IaasCustomImage (PaaS* is
deprecated).

For the size of the compute node -- make sure that the sizing is
supported for both Azure Batch and the selected OS, see
[here](https://docs.microsoft.com/en-us/azure/batch/batch-pool-vm-sizes)

Under the Publisher, Offer, and Sku, for this example use case choose
for *Publisher* "*microsoftwindowsserver*" with a *Offer* of
"*windowsserver*" and choose an appropriate *Sku*.

Next set *VNet (Subnet Id)* like:

> /subscriptions/{SUBSCRIPTION GUID}/resourceGroups/{RESOURCE GROUP
> NAME}/providers/Microsoft.Network/virtualNetworks/{VNET
> NAME}/subnets/{SUBNET NAME}

Lastly for the *Mount Configurations* this is a json, configuration of
the type:

> { \"Type\":\"AzureFiles\",
> \"AccountName\":\"{STORAGE_ACCOUNT_NAME\]\", \"AccountKey\":\"{STORAGE
> SAS TOKEN} \",
> \"AzureFileUrl\":\"https://{STORAGE_ACCOUNT_NAME}.file.core.windows.net/{SHARENAME\]\",
> \"MountPath\":\"{MOUNTED DRIVE LETTER\]\",
> \"MountOptions\":\"/persistent:Yes\" }

Select Next: Deploy jobs to the Azure Batch pool as normal (tip: for
Windows add cmd /c for the task).

*Resources:*

[Adding the Azure Batch Pool]{.ul}:
<https://docs.microsoft.com/en-us/powershell/high-performance-computing/burst-to-azure-batch-with-microsoft-hpc-pack?view=hpc19-ps#BKMK_Add>

[Azure Batch Support VM Sizes]{.ul}:
https://docs.microsoft.com/en-us/azure/batch/batch-pool-vm-sizes
