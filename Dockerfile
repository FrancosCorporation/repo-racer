FROM nginx:1.31.6-alpine3.24

# Jogo 100% estatico: nao existe etapa de build, so servir os arquivos
COPY index.html LICENSE /usr/share/nginx/html/
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
RUN rm -f /usr/share/nginx/html/50x.html

EXPOSE 80
