---
haproxy:
  # use lookup section to override 'map.jinja' values
  #lookup:
    #user: 'custom-user'
    #group: 'custom-group'
    # new setting to override configuration file path
    #config_file: /etc/haproxy/haproxy.cfg
  enabled: True
  overwrite: True # Overwrite an existing config file if present (default behaviour unless set to false)
  # old setting to override configuration file path, kept for compatibility
  #config_file_path: /etc/haproxy/haproxy.cfg
  global:
    log:
      - 127.0.0.1 local2
      - 127.0.0.1 local1 notice
    # Option log-tag parameter, sets the tag field in the syslog header
    log-tag: haproxy
    # Optional log-send-hostname parameter, sets the hostname field in the syslog header
    log-send-hostname: localhost
    stats:
      enable: True
      socketpath: /var/lib/haproxy/stats
      mode: 660
      level: admin
      # Optional extra bind parameter, for example to set the owner/group on the socket file
      extra: user haproxy group haproxy
    ssl-default-bind-ciphers: "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384"
    ssl-default-bind-options: "no-sslv3 no-tlsv10 no-tlsv11"

    user: haproxy
    group: haproxy
    chroot:
      enable: True
      path: /var/lib/haproxy

    daemon: True


  userlists:
    userlist1:
      users:
        john: insecure-password doe
        sam: insecure-password frodo
#      groups:
#        admins: users john sam
#        guests: users jekyll hyde jane

  defaults:
    log: global
    mode: http
    retries: 3
    options:
      - httplog
      - dontlognull
      - forwardfor
      - http-server-close
    logformat: "%ci:%cp\\ [%t]\\ %ft\\ %b/%s\\ %Tq/%Tw/%Tc/%Tr/%Tt\\ %ST\\ %B\\ %CC\\ %CS\\ %tsc\\ %ac/%fc/%bc/%sc/%rc\\ %sq/%bq\\ %hr\\ %hs\\ %{+Q}r"
    timeouts:
      - http-request    10s
      - queue           1m
      - connect         10s
      - client          1m
      - server          1m
      - http-keep-alive 10s
      - check           10s
    stats:
      - enable
      - uri: '/admin?stats'
      - realm: 'Haproxy\ Statistics'
      - auth: 'admin1:AdMiN123'

    # errorfiles:
    #   400: /etc/haproxy/errors/400.http
    #   403: /etc/haproxy/errors/403.http
    #   408: /etc/haproxy/errors/408.http
    #   500: /etc/haproxy/errors/500.http
    #   502: /etc/haproxy/errors/502.http
    #   503: /etc/haproxy/errors/503.http
    #   504: /etc/haproxy/errors/504.http

  {# Suported by HAProxy 1.6 #}
  resolvers:
    local_dns:
      options:
        - nameserver resolvconf 127.0.0.1:53
        - resolve_retries 3
        - timeout retry 1s
        - hold valid 10s


  listens:
    stats:
      bind:
        - "0.0.0.0:8998"
      mode: http
      stats:
        enable: True
        uri: "/admin?stats"
        refresh: "20s"
    myservice:
      bind:
        - "*:8888"
      options:
        - forwardfor
        - http-server-close
      defaultserver:
        slowstart: 60s
        maxconn: 256
        maxqueue: 128
        weight: 100
      servers:
        web1:
          host: web1.example.com
          port: 80
          check: check
        web2:
          host: web2.example.com
          port: 18888
          check: check
        web3:
          host: web3.example.com
    redis:
      bind:
        - '*:6379'
      balance: roundrobin
      defaultserver:
        fall: 3
      options:
        - tcp-check
      tcpchecks:
        - send PINGrn
        - expect string +PONG
        - send info replicationrn
        - expect string role:master
        - send QUITrn
        - expect string +OK
      servers:
        server1:
          host: server1
          port: 6379
          check: check
          extra: port 6379 inter 1s
        server2:
          host: server2
          port: 6379
          check: check
          extra: port 6379 inter 1s backup
  frontends:
    frontend1:
      name: www-http
      bind: "*:80"
      redirects:
        - scheme https if !{ ssl_fc }
      reqadds:
        - "X-Forwarded-Proto:\\ http"
      default_backend: www-backend

#    www-https:
#      bind: "*:443 ssl crt /etc/ssl/private/certificate-chain-and-key-combined.pem"
#      logformat: "%ci:%cp\\ [%t]\\ %ft\\ %b/%s\\ %Tq/%Tw/%Tc/%Tr/%Tt\\ %ST\\ %B\\ %CC\\ %CS\\ %tsc\\ %ac/%fc/%bc/%sc/%rc\\ %sq/%bq\\ %hr\\ %hs\\ %{+Q}r\\ ssl_version:%sslv\\ ssl_cipher:%sslc"
#      reqadds:
#        - "X-Forwarded-Proto:\\ https"
#      default_backend: www-backend
#      acls:
#        - url_static       path_beg       -i /static /images /javascript /stylesheets
#        - url_static       path_end       -i .jpg .gif .png .css .js
#      use_backends:
#        - static-backend  if url_static
#      extra: "rspadd  Strict-Transport-Security:\ max-age=15768000"
#    some-services:
#      bind:
#        - "*:8080"
#        - "*:8088"
#      default_backend: api-backend

  backends:
    backend1:
      name: www-backend
      balance: roundrobin
      redirects:
        - scheme https if !{ ssl_fc }
      extra: "reqidel ^X-Forwarded-For:"
      servers:
        server1:
          name: server1-its-name
          host: 192.168.1.213
          port: 80
          check: check
    static-backend:
      balance: roundrobin
      redirects:
        - scheme https if !{ ssl_fc }
      options:
        - http-server-close
        - httpclose
        - forwardfor    except 127.0.0.0/8
        - httplog
      cookie: "pm insert indirect"
      stats:
        enable: True
        uri: /url/to/stats
        realm: LoadBalancer
        auth: "user:password"
      servers:
        some-server:
          host: 123.156.189.111
          port: 8080
          check: check
        another-server:
          host: 123.156.189.112
    api-backend:
      options:
        - http-server-close
        - forwardfor
      servers:
        apiserver1:
          host: apiserver1.example.com
          port: 80
          check: check
        server2:
          name: apiserver2
          host: apiserver2.example.com
          port: 80
          check: check
          extra: resolvers local_dns resolve-prefer ipv4
    another_www:
      mode: tcp
      balance: source
      sticktable: "type binary len 32 size 30k expire 30m"
      acls:
        - clienthello req_ssl_hello_type 1
        - serverhello rep_ssl_hello_type 2
      tcprequests:
        - "inspect-delay 5s"
        - "content accept if clienthello"
      tcpresponses:
        - "content accept if serverhello"
      stickons:
        - "payload_lv(43,1) if clienthello"
      reqreps:
        - '^([^\ :]*)\ /static/(.*) \1\ \2'
      options: "ssl-hello-chk"
