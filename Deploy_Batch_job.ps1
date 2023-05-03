######
## Script run a job against a pre-existing pool
##      This script begins with a startup task of mapping a drive
##          then executes a "script" and captures the output to that shared drive.
#####

Import-Module Az.Batch

# Define variables
$batchResourceGroupName =   "{BATCH_RESOURCE_GROUP}"    # Ex. rg-deve1batch01 
$batchAccountName =         "{BATCH_ACCOUNT_NAME}"      # Ex. batdeve1iaac01
$subscription =             "{SUBSCRIPTION_NAME}"       # Ex. HR_DEV_Subscription
$batchPoolName =            "{POOL_NAME}"               # Ex. bpdemo001

#   Verify that the S: drive is mapped as part of pool startup or can be used for any pre-job verification tasks
$prepTaskCli =              'powershell -Command "$driveChk = test-path "S:"; if($driveChk -eq $false) { Write-Error "S: Drive Not Mapped"}"'
$jobID =                    "{BATCH_JOB_ID}"            # Ex. jobiaac001
$taskID =                   "{TASK_ID}"                 # Ex. task01
$taskDN =                   "{TASK_DISPLAY_NAME}"       # Ex. TaskSecurityLogs01
$taskOutputFile =           "s:\" + $(Get-Date -Format yy-MM-dd-HH_MM_ss) + ".txt"
$taskPSCLI =                "Get-EventLog -Logname Security -newest 100 | Out-File -Append -FilePath " + $taskOutputFile
$taskCLI =                  "powershell -Command " + $taskPSCLI

$prepTskName =              "{JOB_PREPARATION_TASK}"    # Ex. valdrvtask02
$displayName =              "{JOB_PREP_DISPLAY_NAME}"   # Ex. Validate Drive Mapping

$commonEnvSettings =        New-Object System.Collections.Generic.Dictionary"[String,String]"
$commonEnvSettings.Add(     "jobID", $jobID)


$PSJobPreptask =            New-Object Microsoft.Azure.Commands.Batch.Models.PSJobPreparationTask

$maxTaskRetryCount = 1
#   Permit this task to retain for 10 minutes
$retentionTime = New-Object System.TimeSpan(0, 10, 0)
#   Permit this task to try for 1 minute
$maxPrepWallClockTime = New-Object System.TimeSpan(0, 1, 0)

$PSJobPrepconst =           New-Object Microsoft.Azure.Commands.Batch.Models.PSTaskConstraints($maxPrepWallClockTime, $retentionTime, $maxTaskRetryCount)

$PSJobPreptask.CommandLine= $prepTaskCli
$PSJobPreptask.Id =         $prepTskName
$PSJobPreptask.RerunOnComputeNodeRebootAfterSuccess = $true
$PSJobPreptask.WaitForSuccess = $true
$PSJobPreptask.Constraints= $PSJobPrepconst

#   Task to run
$PSJobMGRtask =             New-Object Microsoft.Azure.Commands.Batch.Models.PSJobManagerTask
$maxTaskRetryCount = 1
#   Permit this task to retain for 10 minutes
$retentionTime = New-Object System.TimeSpan(0, 10, 0)
#   Permit this task to try for 3 minutes
$maxWallClockTime = New-Object System.TimeSpan(0, 3, 0)

$PSJobMGRconst =            New-Object Microsoft.Azure.Commands.Batch.Models.PSTaskConstraints($maxWallClockTime, $retentionTime, $maxTaskRetryCount)
# Execute the command as a Batch Autouser with Admin privileges
$PSJobMGRtask.UserIdentity= New-Object Microsoft.Azure.Commands.Batch.Models.PSUserIdentity(New-Object Microsoft.Azure.Commands.Batch.Models.PSAutoUserSpecification(1, 1))
$PSJobMGRtask.AllowLowPriorityNode = $true
#   $PSJobMGRtask.ApplicationPackageReferences 
$PSJobMGRtask.ID =          $taskID
$PSJobMGRtask.CommandLine = $taskCLI
$PSJobMGRtask.DisplayName = $taskDN
$PSJobMGRtask.Constraints = $PSJobMGRconst

# Connect and poll local variables
Connect-AzAccount 
Select-AzSubscription -SubscriptionName $subscription


$context =                  Get-AzBatchAccount -ResourceGroupName $batchResourceGroupName -AccountName $batchAccountName
$pool =                     Get-AzBatchPool -BatchContext $context -Id $batchPoolName
$poolInformation =          New-Object Microsoft.Azure.Commands.Batch.Models.PSPoolInformation
$poolInformation.PoolId =   $pool.Id


New-AzBatchJob -Id $jobID `
-CommonEnvironmentSettings $commonEnvSettings `
-DisplayName $displayName `
-JobPreparationTask $PSJobPreptask `
-JobManagerTask $PSJobMGRtask `
-PoolInformation $poolInformation `
-BatchContext $context