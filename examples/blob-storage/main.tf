resource "humanitec_application" "example" {
  id   = var.name
  name = var.name
}

locals {
  # Classes used to build the resource definition graph
  blob_storage_basic_class         = "basic"
  blob_storage_admin_policy_class  = "blob-storage-basic-admin"
  blob_storage_reader_policy_class = "blob-storage-basic-reader"

  # Classes that developers can select from
  blob_storage_admin_class  = "basic-admin"
  blob_storage_reader_class = "basic-read-ony"

  blob_storage_scope = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/$${resources['azure-blob.${local.blob_storage_basic_class}'].outputs.account}/blobServices/default/containers/$${resources['azure-blob.${local.blob_storage_basic_class}'].outputs.container}"

  # Azure build in role ids: https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
  build_in_azure_storage_blob_data_owner_role_id  = "/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b"
  build_in_azure_storage_blob_data_reader_role_id = "/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
}

module "blob_storage" {
  source = "../../humanitec-resource-defs/azure-blob/basic"

  resource_packs_azure_url = var.resource_packs_azure_url
  resource_packs_azure_rev = var.resource_packs_azure_rev
  client_id                = var.client_id
  client_secret            = var.client_secret
  tenant_id                = var.tenant_id
  subscription_id          = var.subscription_id
  resource_group_name      = var.resource_group_name
  prefix                   = var.prefix
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  container_name           = var.container_name
  container_access_type    = var.container_access_type
}

resource "humanitec_resource_definition_criteria" "blob_storage" {
  resource_definition_id = module.blob_storage.id
  app_id                 = humanitec_application.example.id
  class                  = local.blob_storage_basic_class
}

// Admin shared

// Exposed delegator resource definition
module "blob_storage_admin" {
  source = "../../humanitec-resource-defs/azure-blob/delegator"

  prefix                      = "${var.prefix}admin-"
  policy_resource_class       = local.blob_storage_admin_policy_class
  blob_storage_resource_class = local.blob_storage_basic_class
}

resource "humanitec_resource_definition_criteria" "blob_storage_admin" {
  resource_definition_id = module.blob_storage_admin.id
  app_id                 = humanitec_application.example.id
  class                  = local.blob_storage_admin_class
}

module "role_definition_admin" {
  source = "../../humanitec-resource-defs/azure-role-definition/echo"

  prefix = "${var.prefix}admin-"

  role_definition_id    = local.build_in_azure_storage_blob_data_owner_role_id
  role_definition_scope = local.blob_storage_scope
}

resource "humanitec_resource_definition_criteria" "role_definition_admin" {
  resource_definition_id = module.role_definition_admin.id
  app_id                 = humanitec_application.example.id
  class                  = local.blob_storage_admin_policy_class
}

// Reader shared

// Exposed delegator resource definition
module "blob_storage_reader" {
  source = "../../humanitec-resource-defs/azure-blob/delegator"

  prefix                      = "${var.prefix}reader-"
  policy_resource_class       = local.blob_storage_reader_policy_class
  blob_storage_resource_class = local.blob_storage_basic_class
}

resource "humanitec_resource_definition_criteria" "blob_storage_reader" {
  resource_definition_id = module.blob_storage_reader.id
  app_id                 = humanitec_application.example.id
  class                  = local.blob_storage_reader_class
}

module "role_definition_reader" {
  source = "../../humanitec-resource-defs/azure-role-definition/echo"

  prefix = "${var.prefix}reader-"

  role_definition_id    = local.build_in_azure_storage_blob_data_reader_role_id
  role_definition_scope = local.blob_storage_scope
}

resource "humanitec_resource_definition_criteria" "role_definition_reader" {
  resource_definition_id = module.role_definition_reader.id
  app_id                 = humanitec_application.example.id
  class                  = local.blob_storage_reader_policy_class
}

// Workload based

module "workload" {
  source = "../../humanitec-resource-defs/workload/service-account"

  prefix = var.prefix
}

resource "humanitec_resource_definition_criteria" "workload" {
  resource_definition_id = module.workload.id
  app_id                 = humanitec_application.example.id
}

module "k8s_service_account" {
  source = "../../humanitec-resource-defs/k8s/service-account"

  prefix = var.prefix
}

resource "humanitec_resource_definition_criteria" "k8s_service_account" {
  resource_definition_id = module.k8s_service_account.id
  app_id                 = humanitec_application.example.id
}

module "federated_identity" {
  source = "../../humanitec-resource-defs/azure-federated-identity/basic"

  resource_packs_azure_url = var.resource_packs_azure_url
  resource_packs_azure_rev = var.resource_packs_azure_rev

  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  prefix = var.prefix

  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_cluster_issuer_url
  parent_id           = "$${resources.azure-managed-identity.outputs.id}"
  subject             = "system:serviceaccount:$${resources.k8s-namespace.outputs.namespace}:$${resources.k8s-service-account.outputs.name}"
}

resource "humanitec_resource_definition_criteria" "federated_identity" {
  resource_definition_id = module.federated_identity.id
  app_id                 = humanitec_application.example.id
}

module "managed_identity" {
  source = "../../humanitec-resource-defs/azure-managed-identity/basic"

  resource_packs_azure_url = var.resource_packs_azure_url
  resource_packs_azure_rev = var.resource_packs_azure_rev

  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  prefix              = var.prefix
  resource_group_name = var.resource_group_name
}

resource "humanitec_resource_definition_criteria" "managed_identity" {
  resource_definition_id = module.managed_identity.id
  app_id                 = humanitec_application.example.id
}

module "role_assignment" {
  source = "../../humanitec-resource-defs/azure-role-assignments/basic"

  resource_packs_azure_url = var.resource_packs_azure_url
  resource_packs_azure_rev = var.resource_packs_azure_rev

  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  prefix              = var.prefix
  role_definition_ids = "$${resources.workload>azure-role-definition.outputs.id}"
  scopes              = "$${resources.workload>azure-role-definition.outputs.scope}"
  principal_id        = "$${resources.azure-managed-identity.outputs.principal_id}"
}

resource "humanitec_resource_definition_criteria" "role_assignment" {
  resource_definition_id = module.role_assignment.id
  app_id                 = humanitec_application.example.id
}
