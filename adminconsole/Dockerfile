FROM node:20-alpine AS build
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

ARG VITE_API_URL=http://localhost:8080
ENV VITE_API_URL=$VITE_API_URL

RUN npm run build

FROM nginx:1.27-alpine AS final
COPY --from=build /app/dist /usr/share/nginx/html
# La imagen oficial de nginx procesa con envsubst los archivos *.template de estas carpetas al arrancar.
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
ENV API_ORIGIN=http://localhost:8080

EXPOSE 80
