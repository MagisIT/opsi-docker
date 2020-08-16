# -*- coding: utf-8 -*-
# Automatically generated file from docker-entrypoint.sh
# 
# Any modifications with Active Directory Integration enabled may not persist after restart!


backend_deleteBase     : sys_group(opsiadmin); {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
backend_.*             : all
hostControl.*          : sys_group(opsiadmin); opsi_depotserver; {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
host_get.*             : sys_group(opsiadmin); opsi_depotserver; self; opsi_client(attributes(!opsiHostKey,!description,!lastSeen,!notes,!hardwareAddress,!inventoryNumber)); {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
auditSoftware_delete.* : sys_group(opsiadmin); opsi_depotserver; {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
auditSoftware_.*       : sys_group(opsiadmin); opsi_depotserver; opsi_client; {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
auditHardware_delete.* : sys_group(opsiadmin); opsi_depotserver; {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
auditHardware_.*       : sys_group(opsiadmin); opsi_depotserver; opsi_client; {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
user_setCredentials    : sys_group(opsiadmin); opsi_depotserver; {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
user_getCredentials    : opsi_depotserver; opsi_client
.*_get.*               : sys_group(opsiadmin); opsi_depotserver; opsi_client; {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
get(Raw){0,1}Data      : sys_group(opsiadmin); opsi_depotserver; {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
.*                     : sys_group(opsiadmin); opsi_depotserver; {{if eq .ENABLE_AD "true"}} sys_group({{ .AD_OPSI_GROUP }}) {{end}}
