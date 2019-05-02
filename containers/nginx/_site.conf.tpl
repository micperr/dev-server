server {
    listen 80;
    root {$WEB_PATH};
    server_name {$SERVER_NAME};

    charset utf-8;
    sendfile off;

    # fastcgi_keep_conn on;
    fastcgi_buffer_size 256k;
    fastcgi_buffers 8 512k;
    fastcgi_busy_buffers_size 512k;
    client_max_body_size 0;

    access_log off;
    error_log  /var/log/nginx/{$LOG_FILE}.log error;

    include /etc/nginx/conf.d/sitetypes/{$SITE_TYPE}.conf;

    error_page 404 /404.html;
    location = /404.html {
        root /;
        internal;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~ /\.ht {
        deny all;
    }
}
