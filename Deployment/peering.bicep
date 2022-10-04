param srcVnetName string
param destVnetName string
param destResourceGroupName string
param srcToDestPeerName string

resource src_vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: srcVnetName
}

resource dest_vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: destVnetName
  scope: resourceGroup(destResourceGroupName)
}

resource primary_peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = {
  name: srcToDestPeerName
  parent: src_vnet
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: dest_vnet.id
    }
  }
}
