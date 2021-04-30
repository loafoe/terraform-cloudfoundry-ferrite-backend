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
  strategy     = "blue-green"

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

  service_binding {
    service_instance = cloudfoundry_service_instance.database.id
  }

}

resource "hsdp_container_host" "worker" {
  name            = "ferrite-worker-${local.postfix_name}.${var.cartel_postfix}"
  volumes         = 1
  volume_size     = var.volume_size
  instance_type   = var.instance_type
  user_groups     = var.user_groups
  security_groups = var.security_groups
  subnet_type     = "public"
}

resource "hsdp_container_host_exec" "worker" {
  triggers = {
    instance_ids    = hsdp_container_host.worker.id
    bash            = file("${path.module}/templates/bootstrap-worker.sh")
    docker_username = var.docker_username
    docker_password = var.docker_password
    docker_image    = var.ferrite_image
    private_ip      = hsdp_container_host.worker.private_ip
  }

  bastion_host = data.hsdp_config.gateway.host
  host         = hsdp_container_host.worker.private_ip
  user         = var.cartel_user
  private_key  = var.private_key

  file {
    content = templatefile("${path.module}/templates/local.yml", {
      private_ip = hsdp_container_host.worker.private_ip
      hostname   = cloudfoundry_service_key.database_key.credentials["hostname"]
      db_name    = cloudfoundry_service_key.database_key.credentials["db_name"]
      password   = cloudfoundry_service_key.database_key.credentials["password"]
      username   = cloudfoundry_service_key.database_key.credentials["username"]
      port       = cloudfoundry_service_key.database_key.credentials["port"]
      uri        = cloudfoundry_service_key.database_key.credentials["uri"]
    })
    destination = "/home/${var.cartel_user}/local.yml"
    permissions = "0600"
  }

  file {
    content = templatefile("${path.module}/templates/bootstrap-worker.sh", {
      docker_username = var.docker_username
      docker_password = var.docker_password
      docker_image    = var.ferrite_image
      private_ip      = hsdp_container_host.worker.private_ip
      user            = var.cartel_user
    })
    destination = "/home/${var.cartel_user}/bootstrap-worker.sh"
    permissions = "0700"
  }

  commands = [
    "/home/${var.cartel_user}/bootstrap-worker.sh"
  ]
}

resource "cloudfoundry_app" "hsdp_func_gateway" {
  count        = var.enable_gateway ? 1 : 0
  name         = "hsdp-func-gateway-${local.postfix_name}"
  space        = local.space_id
  memory       = var.gateway_memory
  disk_quota   = var.gateway_disk_quota
  docker_image = var.function_gateway_image
  strategy     = "blue-green"

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
      BACKEND_TYPE : "ferrite"
      IRON_CONFIG : templatefile("${path.module}/templates/iron_config.json", {
        token    = random_password.password.result
        base_url = "https://${cloudfoundry_route.ferrite.endpoint}/"
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

resource "cloudfoundry_service_instance" "database" {
  name         = "ferrite-rds"
  space        = local.space_id
  service_plan = data.cloudfoundry_service.rds.service_plans[var.db_plan]
  json_params  = var.db_json_params
}

resource "cloudfoundry_service_key" "database_key" {
  name             = "key"
  service_instance = cloudfoundry_service_instance.database.id
}
