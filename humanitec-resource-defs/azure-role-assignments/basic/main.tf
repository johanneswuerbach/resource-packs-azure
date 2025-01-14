resource "humanitec_resource_definition" "main" {
  driver_type = "humanitec/terraform"
  id          = "${var.prefix}role-assignment-basic"
  name        = "${var.prefix}role-assignment-basic"
  type        = "azure-role-assignments"

  driver_inputs = {
    secrets_string = jsonencode({
      variables = {
        client_id     = var.client_id
        client_secret = var.client_secret
      }
    })

    values_string = jsonencode({
      source = {
        path = "modules/azure-role-assignments/basic"
        rev  = var.resource_packs_azure_rev
        url  = var.resource_packs_azure_url
      }

      variables = {
        res_id = "$${context.res.id}"
        app_id = "$${context.app.id}"
        env_id = "$${context.env.id}"

        name                = var.name
        tenant_id           = var.tenant_id
        subscription_id     = var.subscription_id
        prefix              = var.prefix
        role_definition_ids = var.role_definition_ids
        scopes              = var.scopes
        principal_id        = var.principal_id
      }
    })
  }
}
