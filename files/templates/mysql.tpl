# -*- coding: utf-8 -*-

module = 'MySQL'
config = {
    "username": "{{ .MYSQL_USER}}", 
    "connectionPoolMaxOverflow": 10, 
    "database": "{{ .MYSQL_DATABASE }}", 
    "connectionPoolTimeout": 30, 
    "address": "{{ .MYSQL_HOST }}", 
    "password": "{{ .MYSQL_PASSWORD }}", 
    "databaseCharset": "utf8", 
    "connectionPoolSize": 20
}