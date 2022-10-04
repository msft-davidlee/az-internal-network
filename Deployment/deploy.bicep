param location string
param deployPublicIp string
param prefix string
param sourceIp string
param ipPrefix string

var networkPrefix = toLower('${prefix}-${location}')

var subnets = [
  'default'
  'ase'
  'aks'
  'aci'
  'appsvccs'
  'appsvcaltid'
  'appsvcpartapi'
  'appsvcbackend'
  'appgw'
  // Typically, we are using /24 to define subnet size. However, note that Azure Container Apps 
  // subnets are special because they require a larger subnet size so if we are adding a new subnet, 
  // it should be added on top of this comment as we are using the index of array as the subnet like 
  // ipPrefix.0.0.0/24 would be for default, ipPrefix.0.1.0/24 would be for ase etc.
  'containerappcontrol'
  'containerapp'
]

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: '${networkPrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '${ipPrefix}.0.0.0/16'
      ]
    }
    subnets: [for (subnetName, i) in subnets: {
      name: subnetName
      properties: {
        addressPrefix: (subnetName == 'containerappcontrol') ? '${ipPrefix}.0.96.0/21' : (subnetName == 'containerapp') ? '${ipPrefix}.0.104.0/21' : '${ipPrefix}.0.${i}.0/24'
      }
    }]
  }
}

var allowHttp = {
  name: 'AllowHttp'
  properties: {
    description: 'Allow HTTP'
    priority: 100
    protocol: 'Tcp'
    direction: 'Inbound'
    access: 'Allow'
    sourceAddressPrefixes: sourceIp
    sourcePortRange: '*'
    destinationPortRange: '80'
    destinationAddressPrefixes: '*'
  }
}

var allowHttps = {
  name: 'AllowHttps'
  properties: {
    description: 'Allow HTTPS'
    priority: 110
    protocol: 'Tcp'
    direction: 'Inbound'
    access: 'Allow'
    sourceAddressPrefixes: sourceIp
    sourcePortRange: '*'
    destinationPortRange: '443'
    destinationAddressPrefixes: '*'
  }
}

var allowFrontdoorOnHttp = {
  name: 'AllowFrontdoorHttp'
  properties: {
    description: 'Allow Frontdoor on HTTPS'
    priority: 120
    protocol: 'Tcp'
    direction: 'Inbound'
    access: 'Allow'
    sourceAddressPrefixes: 'AzureFrontDoor.Backend'
    sourcePortRange: '*'
    destinationPortRange: '80'
    destinationAddressPrefixes: '*'
  }
}

var allowFrontdoorOnHttps = {
  name: 'AllowFrontdoorHttps'
  properties: {
    description: 'Allow Frontdoor on HTTPS'
    priority: 130
    protocol: 'Tcp'
    direction: 'Inbound'
    access: 'Allow'
    sourceAddressPrefixes: 'AzureFrontDoor.Backend'
    sourcePortRange: '*'
    destinationPortRange: '443'
    destinationAddressPrefixes: '*'
  }
}

// See: https://docs.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#network-security-groups
var allowAppGatewayV2 = {
  name: 'AllowApplicationGatewayV2Traffic'
  properties: {
    description: 'Allow Application Gateway V2 traffic'
    priority: 140
    protocol: 'Tcp'
    direction: 'Inbound'
    access: 'Allow'
    sourceAddressPrefixes: 'GatewayManager'
    sourcePortRange: '*'
    destinationPortRange: '65200-65535'
    destinationAddressPrefixes: '*'
  }
}

resource nsgs 'Microsoft.Network/networkSecurityGroups@2022-01-01' = [for subnetName in subnets: {
  name: '${networkPrefix}-${subnetName}-subnet-nsg'
  location: location
  properties: {
    securityRules: (subnetName == 'aks' || startsWith(subnetName, 'containerapp')) ? [
      allowHttp
      allowHttps
      allowFrontdoorOnHttp
      allowFrontdoorOnHttps
    ] : (subnetName == 'appgw') ? [
      allowHttp
      allowHttps
      allowAppGatewayV2
    ] : []
  }
}]

// Note that all changes related to the subnet must be done on this level rathter than
// on the Virtual network resource declaration above because otherwise, the changes
// may be overwritten on this level.

@batchSize(1)
resource associatensg 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = [for (subnetName, i) in subnets: {
  name: '${vnet.name}/${subnetName}'
  properties: {
    addressPrefix: vnet.properties.subnets[i].properties.addressPrefix
    networkSecurityGroup: {
      id: nsgs[i].id
    }
    serviceEndpoints: (startsWith(subnetName, 'appsvc') || subnetName == 'aks') ? [
      {
        service: 'Microsoft.Sql'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.ServiceBus'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
    ] : (subnetName == 'appgw') ? [
      {
        service: 'Microsoft.Web'
        locations: [
          location
        ]
      }
    ] : []
    delegations: (subnetName == 'ase') ? [
      {
        name: 'webapp'
        properties: {
          serviceName: 'Microsoft.Web/hostingEnvironments'
        }
      }
    ] : []
  }
}]

resource aksStaticIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = if (deployPublicIp == 'true') {
  name: '${prefix}-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

output vnetName string = vnet.name
