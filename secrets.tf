#----------------------------------------------------------
# Enable secrets engines
#----------------------------------------------------------
resource "vault_mount" "kv-v2" {
  depends_on = [vault_namespace.finance]
  provider = vault.finance
  path = "kv-v2"
  type = "kv-v2"
}

# Transform secrets engine at root
resource "vault_mount" "mount_transform" {
  path = "transform"
  type = "transform"
}

# Create alphabet
resource "vault_transform_alphabet" "numerics" {
  path = vault_mount.mount_transform.path
  name = "numerics"
  alphabet = "0123456789"
}

resource "vault_transform_alphabet" "alphanumericsupper" {
  path = vault_mount.mount_transform.path
  name = "alphanumericsupper"
  alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
}

# Create transformation template
resource "vault_transform_template" "ccn" {
  path = vault_mount.mount_transform.path
  name = "ccn"
  type = "regex"
  pattern = "(\\d{4})-(\\d{4})-(\\d{4})-(\\d{4})"
  alphabet = vault_transform_alphabet.numerics.name
}

resource "vault_transform_template" "ccn-mask-tmpl" {
  path = vault_mount.mount_transform.path
  name = "ccn-mask-tmpl"
  type = "masking"
  pattern = "(\\d{4})-(\\d{4})-(\\d{4})-\\d{4}"
  alphabet = vault_transform_alphabet.numerics.name
}

resource "vault_transform_template" "ssn" {
  path = vault_mount.mount_transform.path
  name = "ssn"
  type = "regex"
  pattern = "(\\d{3})-(\\d{2})-(\\d{4})"
  alphabet = vault_transform_alphabet.numerics.name
}

resource "vault_transform_template" "ssn-mask-tmpl" {
  path = vault_mount.mount_transform.path
  name = "ssn-mask-tmpl"
  type = "masking"
  pattern = "(\\d{3})-(\\d{2})-\\d{4}"
  alphabet = vault_transform_alphabet.numerics.name
}

# Create a transformation named ccn-fpe
resource "vault_transform_transformation" "ccn-fpe" {
  path = vault_mount.mount_transform.path
  name = "ccn-fpe"
  type = "fpe"
  template = vault_transform_template.ccn.name
  tweak_source = "internal"

  allowed_roles = ["encryption"]
}

resource "vault_transform_transformation" "ccn-mask" {
  path = vault_mount.mount_transform.path
  name = "ccn-mask"
  type = "masking"
  template = vault_transform_template.ccn-mask-tmpl.name
  masking_character = "#"

  allowed_roles = ["partial-decrypt"]
}


# Create a transformation named ssn-fpe
resource "vault_transform_transformation" "ssn-fpe" {
  path = vault_mount.mount_transform.path
  name = "ssn-fpe"
  type = "fpe"
  template = vault_transform_template.ssn.name
  tweak_source = "internal"

  allowed_roles = ["encryption"]
}

resource "vault_transform_transformation" "ssn-mask" {
  path = vault_mount.mount_transform.path
  name = "ssn-mask"
  type = "masking"
  template = vault_transform_template.ssn-mask-tmpl.name
  masking_character = "#"

  allowed_roles = ["partial-decrypt"]
}

# Create a role 
resource "vault_transform_role" "encryption" {
  path = vault_mount.mount_transform.path
  name = "encryption"
  transformations = [vault_transform_transformation.ccn-fpe.name, vault_transform_transformation.ssn-fpe.name]
}

resource "vault_transform_role" "partial-decrypt" {
  path = vault_mount.mount_transform.path
  name = "partial-decrypt"
  transformations = [vault_transform_transformation.ccn-mask.name, vault_transform_transformation.ssn-mask.name]
}



#-------------------------------------------------------------------
# Test the transformation
#-------------------------------------------------------------------
#data "vault_transform_encode" "encoded" {
#  path = vault_transform_role.encryption.path
#  role_name = "encryption"
#  value = "1111-2222-3333-4444"

#  depends_on = [vault_transform_role.encryption]
#}

#output "encoded" {
#  value = data.vault_transform_encode.encoded.encoded_value
#}



# resource "local_file" "encoded" {
#   content = data.vault_transform_encode.encoded.encoded_value
#   filename = "${path.module}/encoded"
# }
#
# data "vault_transform_decode" "decoded" {
#   path = vault_mount.mount_transform.path
#   role_name = vault_transform_role.payments.name
#   #value = data.vault_transform_encode.encoded.encoded_value
#   value = local_file.encoded.content
# }
#
# resource "local_file" "decoded" {
#   content = data.vault_transform_decode.decoded.decoded_value
#   filename = "${path.module}/decoded"
# }
