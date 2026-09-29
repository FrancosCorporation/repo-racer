FROM nginx:alpine

# Jogo 100% estatico: nao existe etapa de build, so servir os arquivos
COPY index.html preview.png LICENSE /usr/share/nginx/html/
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
