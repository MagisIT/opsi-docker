[unix_http_server]
file = /var/run/supervisor.sock

[supervisord]
nodaemon = true

[program:rsyslog]
startsecs = 0
autostart = true
autorestart = true
command = /usr/sbin/rsyslogd -n

[program:smbd]
startsecs = 2
autostart = true
autorestart	= true
process_name = smbd
command	= /usr/sbin/smbd -F -S --no-process-group

[program:opsiconfd]
startsecs = 2
autostart = true
autorestart	= true
process_name = opsiconfd
command	= /usr/bin/opsiconfd
redirect_stderr = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0

[program:tftpserver]
startsecs = 2
autostart = true
autorestart	= true
process_name = tftpserver
command	= /usr/sbin/in.tftpd -v -L --listen --address :69 --secure /tftpboot/ -m /etc/tftpd.map

[program:ssh]
startsecs = 2
autostart = true
autorestart	= true
process_name = ssh
command	= /bin/bash -c "mkdir /run/sshd && /usr/sbin/sshd -D"

[program:cron]
startsecs = 2
autostart = true
autorestart	= true
process_name = cron
command	= /usr/sbin/cron -f

{{if eq .ENABLE_AD "true" }}
[program:winbind]
startsecs = 2
autostart = true
autorestart = true
process_name = winbind
command = /usr/sbin/winbindd -F -S --no-process-group

[program:runtime-init]
autostart = true
autorestart = false
process_name = runtime-init
command = /opt/runtime-init.sh "{{ .AD_OPSI_GROUP }}"
redirect_stderr = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
{{end}}

[eventlistener:process-watcher]
command=/opt/stop-supervisor.sh
events=PROCESS_STATE_EXITED, PROCESS_STATE_FATAL

[supervisorctl]
serverurl = unix:///var/run/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

