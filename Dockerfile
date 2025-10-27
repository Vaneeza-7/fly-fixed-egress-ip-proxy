FROM nginx:alpine

# Copy the nginx configuration file into the container
COPY nginx.conf /etc/nginx/nginx.conf
