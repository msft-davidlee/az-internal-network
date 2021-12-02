param primary_location string
param dr_location string
param environment string
param prefix string
param branch string
param sourceIp string

var tags = {
  'stack-name': prefix
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
  name: '${prefix}-pri-vnet'
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
  name: '${prefix}-dr-vnet'
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
  name: '${prefix}-primary-to-dr-peer'
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
  name: '${prefix}-dr-primary-dr-peer'
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

resource defaultnsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${prefix}-pri-default-subnet'
  location: primary_location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          description: 'Allow SSH'
          priority: 100
          protocol: 'Tcp'
          direction: 'Inbound'
          access: 'Allow'
          sourceAddressPrefix: sourceIp
          sourcePortRange: '*'
          destinationPortRange: '22'
          destinationApplicationSecurityGroups: [
            {
              id: vmasg.id
            }
          ]
        }
      }
    ]
  }
}

resource associatedefaultnsg 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: '${primary_vnet.name}/default'
  properties: {
    addressPrefix: primary_vnet.properties.subnets[0].properties.addressPrefix
    networkSecurityGroup: {
      id: defaultnsg.id
    }
  }
}

resource vmasg 'Microsoft.Network/applicationSecurityGroups@2021-02-01' = {
  name: 'ssh-asg'
  location: primary_location
  tags: tags
}

resource prinsgs 'Microsoft.Network/networkSecurityGroups@2021-02-01' = [for (subnetName, i) in subnets: if (i > 0) {
  name: '${prefix}-pri-${subnetName}-subnet'
  location: primary_location
  tags: tags
}]

resource associateprinsg 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = [for (subnetName, i) in subnets: if (i > 0) {
  name: '${primary_vnet.name}/${subnetName}'
  properties: {
    addressPrefix: primary_vnet.properties.subnets[i].properties.addressPrefix
    networkSecurityGroup: {
      id: prinsgs[i - 1].id
    }
  }
}]
