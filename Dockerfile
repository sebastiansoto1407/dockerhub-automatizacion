FROM nginx:alpine

RUN apk update && apk upgrade --no-cache

COPY . /usr/share/nginx/html

EXPOSE 80