param(
    [Parameter(Mandatory=$true)]
    [string]$tenantId,

    [Parameter(Mandatory=$true)]
    [string]$subscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$applicationName,

    [Parameter(Mandatory=$true)]
    [string]$githubOrg,

    [Parameter(Mandatory=$true)]
    [string]$repoName
)

$context = Get-AzContext  
if (!$context)   
{  
    Login-AzAccount -TenantId $tenantId -SubscriptionId $subscriptionId
}
else
{
    Set-AzContext -TenantId $tenantId -SubscriptionId $subscriptionId
}

New-AzADApplication -DisplayName $applicationName-github-deployer
$clientId = (Get-AzADApplication -DisplayName $applicationName).AppId
$appObjectId = (Get-AzADApplication -DisplayName $applicationName).Id

New-AzADServicePrincipal -ApplicationId $clientId
$objectId = (Get-AzADServicePrincipal -DisplayName $applicationName).Id

New-AzRoleAssignment -RoleDefinitionName Owner -ObjectId $objectId

$subject = 'repo:' + $githubOrg + '/' + $repoName + ':ref:refs/heads/main'
New-AzADAppFederatedCredential -ApplicationObjectId $appObjectId -Audience 'api://AzureADTokenExchange' -Issuer 'https://token.actions.githubusercontent.com' -Name 'GitHub-Actions-MainBranch' -Subject $subject

Write-Host "AZURE_TENANT_ID: $tenantId"
Write-Host "AZURE_SUBSCRIPTION_ID: $subscriptionId"
Write-Host "AZURE_CLIENT_ID: $clientId"
