FROM nginx:alpine

COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./conf.d /etc/nginx/conf.d/
RUN rm /etc/nginx/conf.d/default.conf
