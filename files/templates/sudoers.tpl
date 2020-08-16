Defaults	env_reset
Defaults	mail_badpass
Defaults	secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

root	ALL=(ALL:ALL) ALL

%sudo	ALL=(ALL:ALL) ALL
%opsiadmin  ALL=(ALL:ALL) ALL

{{if eq .ENABLE_AD "true"}}
%{{ shell "printf %q \"${AD_OPSI_GROUP}\"" }} ALL=(ALL:ALL) ALL
{{end}}