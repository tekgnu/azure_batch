########
## Powershell Script to create an Azure Batch Pool
## Based on https://techcommunity.microsoft.com/t5/azure-paas-blog/create-azure-batch-pool-with-powershell/bc-p/3805923#M542
######

#### DEFINE VARIABLES
$batchResourceGroupName =   "rg-deve1batch01" 
$vntResourceGroupName =     "rg-prde1core01"
$batchAccountName =         "batdeve1iaac01"
$subscription =             "matperr_subscription"
$poolName =                 "bpdemo001"
$virtualNetworkName =       "vnt-pe1core01"
$batchSubnetName =          "sbt-10_0_5_0-24"

#   App Package information (for demonstration)
##$applicationName =          "SysInternals"
##$applicationPath =          "C:\tools\sysinternals\SysinternalsSuite.zip"
##$applicationVersion =       "1"

#   User Account for the pool (for demonstration - NEVER KEEP PASSWORDS/TOKENS IN CODE :) )
$userAccountName =          "useraccount01"
$userDemoToken =            "dm0t^f01x18gsn!"
$userRole =                 "admin"

#   Pool Start Task
$startPoolTask =            "cmd /c hostname" # Example Pool Start Task

#   Mounted FileShare
$storageName =              "{STORAGE_NAME001}"
$FQDNShare =                "https://{STORAGE_NAME001}.file.core.windows.net/{SHARE_NAME}" 
$SASToken =                 '{SAS_TOKENT_STRING}'

#   Pool Image Information For a list: Get-AzBatchSupportedImage -BatchContext $(Get-AzBatchAccountKey -AccountName $batchAccountName)
$imgOffer =                 "WindowsServer"
$imgPublisher =             "MicrosoftWindowsServer"
$imgPlan =                  "2019-Datacenter"
$imgBuild =                 "latest"
$imgArch =                  "batch.node.windows amd64"
#   For Custom image
##$nodeAgent =              "batch.node.ubuntu 20.04"
##$imageId =                "/subscriptions/xxxxxxx/resourceGroups/{RESOURCE_GROUP}/providers/Microsoft.Compute/galleries/{IMAGE_GALLERY}/images/{IMAGE_NAME}/versions/{X.Y.Z}"

#   Pool VMs For a list of available sizes: $(Get-AzBatchSupportedVirtualMachineSku -location {REGION}).Name
$VirtualMachineSize =       "Standard_D2ads_v5" 

#   DedicateComputeNodes
$tarDCNodes =               0
#   LowPriorityComputeNodes
$tarLPCNodes =              1

# Connect and poll local variables
Connect-AzAccount
Select-AzSubscription -SubscriptionName $subscription

# Local Variables
$context =                  Get-AzBatchAccount -ResourceGroupName $batchResourceGroupName -AccountName $batchAccountName
$subscriptionId =           $(Get-AzSubscription -SubscriptionName $subscription).id
$virtualNetwork =           Get-AzVirtualNetwork -ResourceGroupName $vntResourceGroupName -Name $virtualNetworkName
$subnetId =                 "/subscriptions/"+$subscriptionId+"/resourceGroups/"+$vntResourceGroupName+"/providers/Microsoft.Network/virtualNetworks/"+$virtualNetworkName+"/subnets/"+$batchSubnetName

# To create the pool the vnet private link and endpoint policies MUST BE DISABLED
($virtualNetwork | Select-Object -ExpandProperty subnets | Where-Object {$_.Name -eq $batchSubnetName} ).privateLinkServiceNetworkPolicies = "Disabled"
($virtualNetwork | Select-Object -ExpandProperty subnets | Where-Object {$_.Name -eq $batchSubnetName}).PrivateEndpointNetworkPolicies = "Disabled"
$virtualNetwork | Set-AzVirtualNetwork

# Setup the network configuration for the pool - Disable Public IP Addressing
$vnetConfig = New-Object Microsoft.Azure.Commands.Batch.Models.PSNetworkConfiguration
$pipConfig = New-Object Microsoft.Azure.Commands.Batch.Models.PSPublicIPAddressConfiguration -ArgumentList @("NoPublicIPAddresses")
$vnetConfig.publicIPAddressConfiguration = $pipConfig
$vnetConfig.SubnetId = $subnetId

# Add the application package from above - THE STORAGE ACCOUNT MUST BE LINKED TO THE BATCH ACCOUNT
##New-AzBatchApplicationPackage -AccountName $batchAccountName -ResourceGroupName $batchResourceGroupName -ApplicationName $applicationName -ApplicationVersion $applicationVersion -FilePath $applicationPath -Format "zip"
##$applicationPackageReference = New-Object Microsoft.Azure.Commands.Batch.Models.PSApplicationPackageReference
##$applicationPackageReference.ApplicationId=$applicationName
##$applicationPackageReference.Version=$applicationVersion
##$applicationPackageArrayReference = New-Object System.Collections.Generic.List[Microsoft.Azure.Commands.Batch.Models.PSApplicationPackageReference]
##$applicationPackageArrayReference.Add($applicationPackageReference)

# Add Certificate to the batch pool - FOR REFERENCE
##$certificatePath="C:\Users\xyz\xxxxx.pfx"
##$certPwd = "xxxxx"
##$securePassword=ConvertTo-SecureString $certPwd –asplaintext –force
##$rawData = [System.IO.File]::ReadAllBytes($certificatePath)
##New-AzBatchCertificate -RawData $rawData -Password $securePassword -BatchContext $context
##$cert = Get-AzBatchCertificate -BatchContext $context
##$certificateReference = New-Object Microsoft.Azure.Commands.Batch.Models.PSCertificateReference
##$certificateReference.Thumbprint = $cert.Thumbprint
##$certificateReference.ThumbprintAlgorithm = $cert.ThumbprintAlgorithm
##$certificateReference.StoreLocation = "LocalMachine"
##$certificateReference.StoreName = "My"
##$certificateReference.Visibility = "StartTask, Task, RemoteUser"
##$certificateArrayReference = New-Object System.Collections.Generic.List[Microsoft.Azure.Commands.Batch.Models.PSCertificateReference]
##$certificateArrayReference.Add($certificateReference)

# Optional Add user account to the batch pool
$userAccount = New-Object Microsoft.Azure.Commands.Batch.Models.PSUserAccount -ArgumentList @($userAccountName, $userDemoToken)
$userAccount.ElevationLevel = $userRole
$userAccount.WindowsUserConfiguration = New-Object Microsoft.Azure.Commands.Batch.Models.PSWindowsUserConfiguration -ArgumentList @("Interactive")

# Optional add Pool Start task launch with account
$startTaskReference = New-Object Microsoft.Azure.Commands.Batch.Models.PSStartTask
# Run as the account from above -
$userIdentity = New-Object Microsoft.Azure.Commands.Batch.Models.PSUserIdentity -ArgumentList($userAccount.Name)
# or as the Pool identity
#$userIdentity = New-Object Microsoft.Azure.Commands.Batch.Models.PSAutoUserSpecification -ArgumentList @("Pool", "Admin") 
$startTaskReference.CommandLine = $startPoolTask
$startTaskReference.UserIdentity= $userIdentity
$startTaskReference.WaitForSuccess=$true
$startTaskReference.MaxTaskRetryCount=1


# Optional Mount a File System via SAS - this may not require SAS based on the instance's identity
$fileShareConfig = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSAzureFileShareConfiguration" -ArgumentList @($storageName, $FQDNShare, "S", $SASToken)
$mountConfig = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSMountConfiguration" -ArgumentList @($fileShareConfig)
## In the example a startup taks is created to ensure that the drive mounted - taken from the Azure Files Script

# Image References Marketplace and Custom example
#   Marketplace Example
$imageReference = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSImageReference" -ArgumentList @($imgOffer, $imgPublisher, $imgPlan, $imgBuild)
$configuration = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSVirtualMachineConfiguration" -ArgumentList @($imageReference, $imgArch)
#   Custom Image Example
##$imageReference = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSImageReference" -ArgumentList @($imageId)
##$configuration = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSVirtualMachineConfiguration" -ArgumentList @($imageReference, $nodeAgent)

# Create the Pool
New-AzBatchPool -Id $poolName `
-VirtualMachineSize $VirtualMachineSize `
-VirtualMachineConfiguration $configuration `
-TargetDedicatedComputeNodes $tarDCNodes `
-TargetLowPriorityComputeNodes $tarLPCNodes `
-NetworkConfiguration $vnetConfig `
-TargetNodeCommunicationMode "Simplified" `
-StartTask $startTaskReference `
-UserAccount $userAccount `
-MountConfiguration @($mountConfig) `
-BatchContext $context

## For adding either Certificates or Application Package References include the following parameters:
# -ApplicationPackageReferences $applicationPackageArrayReference `
# -CertificateReferences $certificateArrayReference `