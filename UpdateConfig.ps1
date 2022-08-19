# Use this script to configure app configuration related to network deployment

$ErrorActionPreference = "Stop"

$ip = (Invoke-RestMethod "https://api.ipify.org?format=json").Ip
$platformRes = (az resource list --tag stack-name='shared-configuration' | ConvertFrom-Json)
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to locate shared configuration."
}

az appconfig kv set -n  $platformRes.name --key "contoso-networking/source-ip" --value $ip --auth-mode login --yes
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to configure source ip."
}