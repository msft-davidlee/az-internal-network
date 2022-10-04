param(
    [Parameter(Mandatory = $true)][string]$BUILD_ENV)

$ErrorActionPreference = "Stop"
# This is the rg where the VNETs should be deployed
$groups = az group list --tag ard-environment=$BUILD_ENV | ConvertFrom-Json
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to query resource groups."
}

$networkingResourceGroup = ($groups | Where-Object { $_.tags.'ard-solution-id' -eq 'networking-pri' }).name
Write-Host "::set-output name=priResourceGroup::$networkingResourceGroup"

$networkingResourceGroup = ($groups | Where-Object { $_.tags.'ard-solution-id' -eq 'networking-dr' }).name
Write-Host "::set-output name=drResourceGroup::$networkingResourceGroup"

$platformRes = (az resource list --tag ard-resource-id=shared-app-configuration | ConvertFrom-Json)
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to locate shared configuration."
}

$sourceIp = az appconfig kv show -n  $platformRes.name --key "contoso-networking/source-ip" --auth-mode login --query "value" -o tsv
if (!$sourceIp) {
    throw "Source IP is required to be configured."
}

if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to get source ip."
}
Write-Host "::set-output name=sourceIp::$sourceIp"

if ($BUILD_ENV -eq "prod") {
    $deployPublicIp = "true"
}
else {
    $deployPublicIp = "false"
}
Write-Host "::set-output name=deployPublicIp::$deployPublicIp"