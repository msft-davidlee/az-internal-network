param primary_location string = 'centralus'
param dr_location string = 'eastus2'
param environment string
param prefix string
param branch string
param sourceIp string

var priNetworkPrefix = toLower('${prefix}-${primary_location}')
var drNetworkPrefix = toLower('${prefix}-${dr_location}')

var tags = {
  'stack-name': '${prefix}-v2'
  'environment': toLower(replace(environment, '_', ''))
  'branch': branch
}

var subnets = [
  'default'
  'ase'
  'aks'
  'aci'
  'appsvccs'
  'appsvcaltid'
  'appsvcpartapi'
  'appsvcbackend'
]

resource primary_vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: '${priNetworkPrefix}-pri-vnet'
  tags: tags
  location: primary_location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [for (subnetName, i) in subnets: {
      name: subnetName
      properties: {
        addressPrefix: '10.0.${i}.0/24'
        serviceEndpoints: (startsWith(subnetName, 'appsvc')) ? [
          {
            service: 'Microsoft.Sql'
            locations: [
              primary_location
            ]
          }
          {
            service: 'Microsoft.Storage'
            locations: [
              primary_location
            ]
          }
          {
            service: 'Microsoft.ServiceBus'
            locations: [
              primary_location
            ]
          }
          {
            service: 'Microsoft.KeyVault'
            locations: [
              primary_location
            ]
          }
        ] : []
      }
    }]
  }
}

resource dr_vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: '${drNetworkPrefix}-dr-vnet'
  tags: tags
  location: dr_location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.16.0.0/16'
      ]
    }
    subnets: [for (subnetName, i) in subnets: {
      name: subnetName
      properties: {
        addressPrefix: '172.16.${i}.0/24'
        serviceEndpoints: (startsWith(subnetName, 'appsvc')) ? [
          {
            service: 'Microsoft.Sql'
            locations: [
              dr_location
            ]
          }
          {
            service: 'Microsoft.Storage'
            locations: [
              dr_location
            ]
          }
          {
            service: 'Microsoft.ServiceBus'
            locations: [
              dr_location
            ]
          }
          {
            service: 'Microsoft.KeyVault'
            locations: [
              dr_location
            ]
          }
        ] : []
      }
    }]
  }
}

resource primary_peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: '${priNetworkPrefix}-pri-to-dr-peer'
  parent: primary_vnet
  dependsOn: [
    primary_vnet
    dr_vnet
  ]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: dr_vnet.id
    }
  }
}

resource dr_peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: '${drNetworkPrefix}-dr-to-pri-peer'
  parent: dr_vnet
  dependsOn: [
    primary_vnet
    dr_vnet
  ]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: primary_vnet.id
    }
  }
}

resource vmasg 'Microsoft.Network/applicationSecurityGroups@2021-02-01' = {
  name: '${priNetworkPrefix}-ssh-asg'
  location: primary_location
  tags: tags
}

var allowHttp = {
  name: 'AllowHttp'
  properties: {
    description: 'Allow HTTP'
    priority: 100
    protocol: 'Tcp'
    direction: 'Inbound'
    access: 'Allow'
    sourceAddressPrefix: sourceIp
    sourcePortRange: '*'
    destinationPortRange: '80'
    destinationAddressPrefix: '*'
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
    sourceAddressPrefix: sourceIp
    sourcePortRange: '*'
    destinationPortRange: '443'
    destinationAddressPrefix: '*'
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
    sourceAddressPrefix: 'AzureFrontDoor.Backend'
    sourcePortRange: '*'
    destinationPortRange: '80'
    destinationAddressPrefix: '*'
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
    sourceAddressPrefix: 'AzureFrontDoor.Backend'
    sourcePortRange: '*'
    destinationPortRange: '443'
    destinationAddressPrefix: '*'
  }
}

resource prinsgs 'Microsoft.Network/networkSecurityGroups@2021-02-01' = [for subnetName in subnets: {
  name: '${priNetworkPrefix}-pri-${subnetName}-subnet-nsg'
  location: primary_location
  tags: tags
  properties: {
    securityRules:  (subnetName == 'aks') ? [
      allowHttp
      allowHttps
      allowFrontdoorOnHttp
      allowFrontdoorOnHttps
    ] : []
  }
}]

@batchSize(1)
resource associateprinsg 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = [for (subnetName, i) in subnets: {
  name: '${primary_vnet.name}/${subnetName}'
  properties: {
    addressPrefix: primary_vnet.properties.subnets[i].properties.addressPrefix
    networkSecurityGroup: {
      id: prinsgs[i].id
    }
  }
}]

resource drnsgs 'Microsoft.Network/networkSecurityGroups@2021-02-01' = [for subnetName in subnets: {
  name: '${drNetworkPrefix}-dr-${subnetName}-subnet-nsg'
  location: dr_location
  tags: tags
}]

@batchSize(1)
resource associatedrnsg 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = [for (subnetName, i) in subnets: {
  name: '${dr_vnet.name}/${subnetName}'
  properties: {
    addressPrefix: dr_vnet.properties.subnets[i].properties.addressPrefix
    networkSecurityGroup: {
      id: drnsgs[i].id
    }
  }
}]
