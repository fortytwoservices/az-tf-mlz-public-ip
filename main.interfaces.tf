module "interfaces" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-interfaces.git?ref=v0.1.0"

  resource_id = azapi_resource.this.id
  location    = var.location
  # Role definitions are looked up by name in the resource group, which exists before the public IP
  # address, so an unknown role name fails during plan.
  role_assignment_definition_scope = var.parent_id
  lock                             = var.lock
  role_assignments                 = var.role_assignments
  diagnostic_settings              = var.diagnostic_settings
  resource_types                   = var.resource_types # its three interface keys are read
  ignore_body_changes              = var.ignore_body_changes
  retry                            = var.retry
  timeouts                         = var.timeouts
}

# v0.1.0 declared these resources here, and module "interfaces" was avm-utl-interfaces.
moved {
  from = azapi_resource.diagnostic_settings
  to   = module.interfaces.azapi_resource.diagnostic_settings
}

moved {
  from = azapi_resource.role_assignments
  to   = module.interfaces.azapi_resource.role_assignments
}

moved {
  from = azapi_resource.lock
  to   = module.interfaces.azapi_resource.lock
}

moved {
  from = time_sleep.lock_removal
  to   = module.interfaces.time_sleep.lock_removal
}

moved {
  from = module.interfaces.random_uuid.role_assignment_name
  to   = module.interfaces.module.avm_interfaces.random_uuid.role_assignment_name
}
