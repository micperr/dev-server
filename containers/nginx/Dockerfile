FROM nginx:alpine

COPY ./conf.d /etc/nginx/conf.d
COPY ./404.html /404.html
RUN rm /etc/nginx/conf.d/default.conf
