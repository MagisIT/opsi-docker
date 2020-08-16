{{if eq .ENABLE_AD "true"}}
[global]
    security = ADS
    workgroup = {{ .AD_DOMAIN }}
    realm = {{ .AD_REALM }}
    winbind use default domain = yes

    idmap config * : backend = tdb
    idmap config * : range = 3000-7999
    idmap config {{ .AD_DOMAIN }} : backend = rid
    idmap config {{ .AD_DOMAIN }} : range = 100000-999999

    template shell = /bin/bash
    template homedir = /home
{{end}}