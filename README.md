# headwind-mdm-docker
Headwind in Docker
[https://h-mdm.com](https://h-mdm.com)

## RUnning the Docker Container

```
docker-compose up -d
```

#### Available environmental variables

- **HMDM_SQL_HOST**: PostgreSQL host (IP or URL) (Default: localhost)
- **HMDM_SQL_PORT**: PostgreSQL port (Default: 5432)
- **HMDM_SQL_DB**: PostgreSQL database (Default: hmdm)
- **HMDM_SQL_USER**: PostgreSQL username (Default: hmdm)
- **HMDM_SQL_PASS**: PostgreSQL password
- **HMDM_PORT**: Tomcat Port to be exposed (extra Option: SAME to keep port by call)
- **HMDM_BASE_PATH**: Tomcat Basepath
- **HMDM_LANGUAGE**: Language (Default: en)
- **HMDM_TOMCAT_PORTOCOL**: Tomcat HTTP Portocol (Options: http | https) (Default: http)

Port Mapping
- **HTTP**   80:80
- **MQTT** 1883:31000

