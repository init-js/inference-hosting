#!/bin/bash

# Check logs

```
docker compose logs -f open-webui
```

# Check pulse

```
curl -I http://127.0.0.1:3000
```

# Configuring tailscale endpoint

in tailscale policy:

```
"autoApprovers": {
  "services": {
    "svc:goose": ["tag:service-host"],
    "svc:chat": ["tag:service-host"]
  }
}
```
Open Services.

- Create or define a service.
- Service name: chat
- Port: 443
- Leave ACL tags identifying this service blank.
- Save it.

Map it:

```
sudo tailscale serve --bg \
  --service=svc:chat \
  --https=443 \
  http://127.0.0.1:3000
```

# Changing docker settings

After updating the compose file, don't forget to
recreate the container.

```
docker compose up -d --force-recreate open-webui
```

# To update open-webui

Change image tag

```
    image: ghcr.io/open-webui/open-webui:v0.11.1
```

update:

```
docker compose pull open-webui
docker compose up -d --force-recreate open-webui
```