# Overview

A small little tool to keep specified A and AAAA Porkbun records up to date with your current dynamic IPv4 and IPv6 addresses.

This is a toy project that was created because I'm learning Zig and wanted to write something in it. 
Please consider a more popular solution instead: [mietzen/porkbun-ddns](https://github.com/mietzen/porkbun-ddns)

But if you are brave enough:

# Getting started

This project is designed to be used as a sidecar to your reverse proxy. I'm running it in the same `docker-compose.yaml` file.
But you should be able to run it raw as long as all of the environment variables are set.

## How it works

1. The service wakes up with a set interval
2. It check its current public IP addresses against the specified DNS records
3. If the IP is different the service will update the record. If the record is missing the service will create the record. The service will NEVER delete a record for you

> It only looks for A (IPv4) and AAAA (IPv6) records and ignores everything else

> At the time of writing, public IPs are discovered with https://i-p.show/

## Example docker-compose.yaml

```yaml
services:
  ddns_ipv4:
    image: cethrivias/zig-porkbun-ddns:latest
    # All variables should support `_FILE` suffix but I've not tested it
    environment:
      - DOMAIN=cethrivias.me
      # Comma separated list. Here: '*' and ''
      - SUB_DOMAINS=*,
      # IP_V4 is enabled by default. Put any other value to disable it
      - IP_V4=TRUE
      # Seconds
      - INTERVAL=600
      # Specified in the .env
      # - API_KEY=[SECRET]
      # - SECRET_KEY=[SECRET]
    env_file:
      - .env

  ddns_ipv6:
    image: cethrivias/zig-porkbun-ddns:latest
    environment:
      - DOMAIN=cethrivias.me
      # No commas, so only 'qnap' here
      - SUB_DOMAINS=qnap
      - IP_V4=nope
      - IP_V6=TRUE
      - INTERVAL=600
    env_file:
      - .env
    # You can also create an IPv6 enabled docker network.
    # But some locked down platforms don't play nice with it.
    # host mode was more reliable for me
    network_mode: "host"
```

You can only manage one domain per container, but it's pretty efficient. You can spawn 40-50 of these instead of one nodejs process

```
CONTAINER ID   NAME          CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O        PIDS
89d059eba3b2   ddns_ipv4     0.00%     832KiB / 62.57GiB     0.00%     28.1kB / 6.93kB   0B / 0B          1
c1fb412ee97a   ddns_ipv6     0.00%     796KiB / 62.57GiB     0.00%     0B / 0B           0B / 0B          1
```
