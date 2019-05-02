server {
    server_name {$DOMAIN};
    listen 80 ;
    location / {
        proxy_pass http://nginx:80; # reference to the container named nginx
        proxy_redirect off;
        proxy_set_header Host {$DOMAIN};
    }

    # Buffering
    # proxy_buffering off;
    # proxy_request_buffering off;

    proxy_buffer_size 256k;
    proxy_buffers 8 512k;
    proxy_busy_buffers_size 512k;
    client_max_body_size 0;

    server_tokens off;
    proxy_max_temp_file_size 0;

    proxy_http_version 1.1;
    proxy_set_header Host $http_host;
    proxy_set_header Upgrade $http_upgrade;
    # proxy_set_header Connection $proxy_connection;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    # proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;
    # proxy_set_header X-Forwarded-Ssl $proxy_x_forwarded_ssl;
    # proxy_set_header X-Forwarded-Port $proxy_x_forwarded_port;
    # Mitigate httpoxy attack (see README for details)
    proxy_set_header Proxy "";
}
