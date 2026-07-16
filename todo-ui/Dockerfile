# Build Stage
FROM node:20-alpine AS build
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci

# Copy remaining source code and build production assets
COPY . .
RUN npm run build -- --configuration production

# Production Stage using Nginx
FROM nginx:alpine
COPY --from=build /app/dist/todo-ui/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
