output "credentials" {
  description = "Siderite credentials"
  value = merge({},
    {
      "type" : "ferrite",
      "siderite_token" : random_password.password.result,
      "siderite_upstream" : join("", cloudfoundry_route.hsdp_func_gateway.*.endpoint),
      "siderite_auth_type" : var.gateway_auth_type,
      "project" : "ff6cfa39faee4928baee01bbddddd549",
      "project_id" : "ff6cfa39faee4928baee01bbddddd549",
      "token" : random_password.password.result,
      "cluster_info_0_cluster_id" : "a1a34bd98a2b44ab9e919cad87826137",
      "cluster_info_0_pubkey" : "-----BEGIN PUBLIC KEY----- MIICCgKCAgEAziySK3sU+4XvHSosRNmZhbVIJdLgynPXsnlSgHhbHbSVlushZ8DH N4+xwJKkijqglv/VtAlsyzH1ppWePjNsbwlqhd/vZxeXYHXWpfnH2vYkEd3+awkc mJB7t1Xb3iiAO6hIIWhaRsRhP19jhCH2foNNxtezv2II5kiMPlnTqvxu9I3Qjazh KQXF/bI13Yjw4cDqld2w0dOMdeb31XHxRIOMOH4X8biPWWzAc0p0MMQ4W2M7X8dx 92VojbUINwZEsSPM135gKL1PCULwnS6QCvYNkmzzjLTfT6iOna/Ze80dBEXwHFkL H5DolfSNXf7/3FjB2BHa64ejZlei3cFlmgNXUGiHUYqfUtjE2P27Cqn2LkQnGMeR k1nniSUgkmFBcCwPmxsrBhsJ0+1ubrplsO2upE9KElR2F7HrKrs9ddBxPA8bJKgC YOlMkG+0kRPCgl8CbSO04qR+pvZimJUYaftnXea/ylBWJ8SOtLgavIAT7eaUMFMQ DhMs5IIgFhHe/zAqnk1vM730bKky47Sc1HDuo3o47l/vRwo5ILDvP3zQepSZ4V3t sxn8LnnurOA9gM7A1cbzZX2g23Zgyfdd0/MsbJtdrnBOO2d6kaGEMzXrLEMqY19n CthjkObtOhPsp/4SXO/ruwlUaLmdzD+wyQH8MI8t9FirCX6dMx7OhhUCAwEAAQ== -----END PUBLIC KEY-----",
      "base_url": "https://${cloudfoundry_route.ferrite.endpoint}/"
    }
  )
  sensitive = true
}

output "token" {
  description = "The authentication token for the gateway"
  value       = random_password.password.result
  sensitive   = true
}

output "api_endpoint" {
  description = "The API endpoint of the gateway (when enabled)"
  value       = join("", cloudfoundry_route.hsdp_func_gateway.*.endpoint)
}

output "auth_type" {
  description = "The API gateway auth type"
  value       = var.gateway_auth_type
}
