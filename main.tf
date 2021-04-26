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
      IRON_CONFIG : templatefile("${path.module}/templates/iron_config.json", {
        cluster_id = "a1a34bd98a2b44ab9e919cad87826137"
        pubkey     = "-----BEGIN PUBLIC KEY----- MIICCgKCAgEAziySK3sU+4XvHSosRNmZhbVIJdLgynPXsnlSgHhbHbSVlushZ8DH N4+xwJKkijqglv/VtAlsyzH1ppWePjNsbwlqhd/vZxeXYHXWpfnH2vYkEd3+awkc mJB7t1Xb3iiAO6hIIWhaRsRhP19jhCH2foNNxtezv2II5kiMPlnTqvxu9I3Qjazh KQXF/bI13Yjw4cDqld2w0dOMdeb31XHxRIOMOH4X8biPWWzAc0p0MMQ4W2M7X8dx 92VojbUINwZEsSPM135gKL1PCULwnS6QCvYNkmzzjLTfT6iOna/Ze80dBEXwHFkL H5DolfSNXf7/3FjB2BHa64ejZlei3cFlmgNXUGiHUYqfUtjE2P27Cqn2LkQnGMeR k1nniSUgkmFBcCwPmxsrBhsJ0+1ubrplsO2upE9KElR2F7HrKrs9ddBxPA8bJKgC YOlMkG+0kRPCgl8CbSO04qR+pvZimJUYaftnXea/ylBWJ8SOtLgavIAT7eaUMFMQ DhMs5IIgFhHe/zAqnk1vM730bKky47Sc1HDuo3o47l/vRwo5ILDvP3zQepSZ4V3t sxn8LnnurOA9gM7A1cbzZX2g23Zgyfdd0/MsbJtdrnBOO2d6kaGEMzXrLEMqY19n CthjkObtOhPsp/4SXO/ruwlUaLmdzD+wyQH8MI8t9FirCX6dMx7OhhUCAwEAAQ== -----END PUBLIC KEY-----"
        user_id    = "notused"
        email      = "notused"
        password   = "notused"
        token      = random_password.password.result
        project    = "ff6cfa39faee4928baee01bbddddd549"
        project_id = "ff6cfa39faee4928baee01bbddddd549"
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
