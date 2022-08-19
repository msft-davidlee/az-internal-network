param(
    [Parameter(Mandatory = $true)][string]$BUILD_ENV)

$ErrorActionPreference = "Stop"
# This is the rg where the VNETs should be deployed
$groups = az group list --tag stack-environment=$BUILD_ENV | ConvertFrom-Json
$networkingResourceGroup = ($groups | Where-Object { 
        $_.tags.'mgmt-id' -eq 'contoso' -and $_.tags.'stack-environment' -eq $BUILD_ENV -and $_.tags.'stack-name' -eq 'networking' }).name
Write-Host "::set-output name=resourceGroup::$networkingResourceGroup"

$prefix = ($groups | Where-Object { 
        $_.tags.'mgmt-id' -eq 'contoso' -and $_.tags.'stack-environment' -eq $BUILD_ENV -and $_.tags.'stack-name' -eq 'shared-services' }).tags.'mgmt-prefix'
Write-Host "::set-output name=prefix::$prefix"

$platformRes = (az resource list --tag stack-name='shared-configuration' | ConvertFrom-Json)
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to locate shared configuration."
}

$sourceIp = az appconfig kv show -n  $platformRes.name --key "contoso-networking/source-ip" --auth-mode login --query "value" -o tsv
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to get source ip."
}
Write-Host "::set-output name=sourceIp::$sourceIp"