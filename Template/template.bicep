param staticSites_name string = 'demo-static-site'

resource staticSites_name_resource 'Microsoft.Web/staticSites@2022-09-01' = {
  name: staticSites_name
  location: 'West US 2'
  sku: {
    name: 'Free'
    tier: 'Free'
  }
}
