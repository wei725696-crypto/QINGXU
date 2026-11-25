ARG NGINX_IMAGE=nginx:stable-alpine
FROM ${NGINX_IMAGE}

COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html app.js style.css /usr/share/nginx/html/

RUN nginx -t

EXPOSE 8080
