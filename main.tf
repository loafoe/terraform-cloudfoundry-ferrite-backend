resource "random_id" "id" {
  byte_length = 8
}

resource "random_password" "password" {
  length  = 32
  special = false
}

locals {
  postfix_name = var.name_postfix != "" ? var.name_postfix : random_id.id.hex
  space_id     = var.cf_space != "" ? join("", data.cloudfoundry_space.space.*.id) : join("", cloudfoundry_space.space.*.id)
}

resource "cloudfoundry_app" "ferrite" {
  name         = "ferrite-${local.postfix_name}"
  space        = local.space_id
  memory       = var.gateway_memory
  disk_quota   = var.gateway_disk_quota
  docker_image = var.ferrite_image

  docker_credentials = {
    username = var.docker_username
    password = var.docker_password
  }

  environment = {
    TOKEN = random_password.password.result
  }

  routes {
    route = cloudfoundry_route.ferrite.id
  }

}

resource "cloudfoundry_app" "hsdp_func_gateway" {
  count        = var.enable_gateway ? 1 : 0
  name         = "hsdp-func-gateway-${local.postfix_name}"
  space        = local.space_id
  memory       = var.gateway_memory
  disk_quota   = var.gateway_disk_quota
  docker_image = var.function_gateway_image

  docker_credentials = {
    username = var.docker_username
    password = var.docker_password
  }
  environment = merge(var.environment,
    {
      GATEWAY_AUTH_TYPE : var.gateway_auth_type
      AUTH_IAM_REGION : var.auth_iam_region
      AUTH_IAM_ENVIRONMENT : var.auth_iam_environment
      AUTH_IAM_ORGS : join(",", var.auth_iam_orgs)
      AUTH_IAM_ROLES : join(",", var.auth_iam_roles)
      AUTH_IAM_CLIENT_ID : var.auth_iam_client_id
      AUTH_IAM_CLIENT_SECRET : var.auth_iam_client_secret
      AUTH_TOKEN_TOKEN : random_password.password.result
      IRON_CONFIG : templatefile("${path.module}/templates/iron_config.json", {
        cluster_id = "cluserid"
        pubkey     = "pubkey-here"
        user_id    = "notused"
        email      = "notused"
        password   = "notused"
        token      = random_password.password.result
        project    = "projectid"
        project_id = "projectid"
        base_url   = "https://${cloudfoundry_route.ferrite.endpoint}/"
      })
    }
  )

  routes {
    route = cloudfoundry_route.hsdp_func_gateway[0].id
  }
}

resource "cloudfoundry_route" "ferrite" {
  domain   = data.cloudfoundry_domain.app_domain.id
  space    = local.space_id
  hostname = "ferrite-${local.postfix_name}"

  depends_on = [cloudfoundry_space_users.users]
}

resource "cloudfoundry_route" "hsdp_func_gateway" {
  count    = var.enable_gateway ? 1 : 0
  domain   = data.cloudfoundry_domain.app_domain.id
  space    = local.space_id
  hostname = "hsdp-func-gateway-${local.postfix_name}"

  depends_on = [cloudfoundry_space_users.users]
}
