param primary_location string
param dr_location string
param environment string
param prefix string
param branch string

var tags = {
  'stack-name': prefix
  'environment': toLower(replace(environment, '_', ''))
  'branch': branch
}

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
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
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
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '172.16.0.0/24'
        }
      }
    ]
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
