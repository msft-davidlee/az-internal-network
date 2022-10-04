$ErrorActionPreference = "Stop"

$ip = (Invoke-RestMethod "https://api.ipify.org?format=json").Ip

az deployment group validate --resource-group networking-dev-pri `
    --template-file .\Deployment\deploy.bicep `
    --parameters ipPrefix=10 sourceIp=$ip location=centralus deployPublicIp=false prefix=pri

if ($LastExitCode -ne 0) {
    throw "An error has occured. Validation failed."
}
    