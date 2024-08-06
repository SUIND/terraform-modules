locals {
  max_length        = 24
  alphanumeric_name = substr(replace(var.name, "/[^a-z0-9]/", ""), 0, local.max_length)
  trimmed_blob_endpoint = trim(azurerm_storage_account.main.primary_blob_endpoint, "/")
  clean_blob_endpoint   = replace(local.trimmed_blob_endpoint, "https://", "")
}

resource "azurerm_storage_account" "main" {
  name                          = local.alphanumeric_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_kind                  = var.kind
  account_tier                  = var.tier
  account_replication_type      = var.replication_type
  access_tier                   = var.access_tier
  https_traffic_only_enabled     = true
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = true
  is_hns_enabled                = var.enable_data_lake
  tags                          = var.tags

  dynamic "queue_properties" {
    for_each = var.queue_properties != null ? toset(["true"]) : toset([])
    content {
      logging {
        delete                = var.queue_properties.logging.delete
        read                  = var.queue_properties.logging.read
        write                 = var.queue_properties.logging.write
        version               = var.queue_properties.logging.version
        retention_policy_days = var.queue_properties.logging.retention_policy_days
      }
    }
  }

  dynamic "blob_properties" {
    for_each = var.blob_properties != null ? toset(["true"]) : toset([])
    content {
      delete_retention_policy {
        days = var.blob_properties.delete_retention_policy
      }
      container_delete_retention_policy {
        days = var.blob_properties.container_delete_retention_policy
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_storage_container" "main" {
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "blob" # enable Anonymous read access for blobs
}

resource "azurerm_cdn_profile" "main" {
  name                = "${azurerm_storage_account.main.name}-cdn"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.cdn_sku
  tags                = var.tags
}

resource "azurerm_cdn_endpoint" "main" {
  name                = "${azurerm_storage_account.main.name}-endpoint"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = var.resource_group_name
  location            = var.location
  is_https_allowed    = true

  is_compression_enabled    = true
  content_types_to_compress = [
    "text/plain",
    "text/css",
    "text/javascript",
    "application/x-javascript",
    "application/javascript",
    "application/json",
    "image/jpeg",
    "image/png"
  ]

  origin {
    name      = azurerm_storage_account.main.name
    host_name = local.clean_blob_endpoint
  }

  tags = var.tags
}