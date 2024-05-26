# Enhanced GitLab Setup with Reverse Proxy, Monitoring, and Visualization

This repository builds upon the [gitlab](https://github.com/AttaKenn/gitlab) by introducing a setup with enhanced monitoring, improved performance and security.

> Note: This [bash script](./install.sh) has been written to simplify the setup. You can go through the script, then just download and run it.

```sudo chmod +x install.sh```

```sudo ./install.sh```

## Updates Included:

### 1. Reverse Proxy Implementation with HAProxy

Integrating HAProxy as a reverse proxy facilitates efficient and secure communication with the GitLab server. By routing traffic through HAProxy, we enhance load balancing, SSL termination, and centralized access control.

#### Configuration

- The HAProxy docker image (```haproxy:latest```) was pulled from Docker Hub. See [docker-compose.yml](./docker-compose.yml). The haproxy is the only container within the ```docker-compose.yml```'s services section with port mappings (exposed ports) to facilitate communication with the upstream backends (GitLab and Grafana containers).

You can click [here](./haproxy/haproxy.cfg) to view the configuration. Below is an in-depth explanation of the configuration.

#### Defaults Section

- **```mode http```:** Sets the default mode to HTTP.
- **```option httpclose```:** Closes the client connection after each response.
- **```option forwardfor```:** Adds the ````X-Forwarded-For```` header to forwarded requsts to preserve the original client IP.
- **```option httpchk```:** Enables HTTP health checks. In this case HAProxy will periodically send HTTP requests to the backend servers to check if they are available and healthy.
- **```timeout client 10s```:** Sets the maximum time (in this case, 10 seconds) that HAProxy will wait for a client to send data after a connection has been established successfully.
- **```timeout connect```:** Sets the maximum time (5 seconds) that HAProxy will wait for a connection to be established with a backend server.
- **```timeout server 10s```:** Sets the maximum time (10 seconds) that HAProxy will wait for a response from a backend server once a connection has been established successfully.
- **```timeout http-request 10s```:** Sets the maximum time (10 seconds) that HAProxy will wait for a complete HTTP request from the client, including the headers and the body.

#### Resolvers Section

- **```parse-resolv-conf```:** Adds all nameservers found in /etc/resolv.conf to this resolvers list (in this case ```dockerdns```).

#### Frontend Sections

As mentioned earlier, the HAProxy container is the only container with exposed ports to facilitate communication.
It has been configured to listen on ports 80, 443, 9090, 3000, and 2222.

> Note: In this project, we utilized **mkcert** to generate a self-signed certificate and the keys for the HTTPS traffic between a client and the proxy (except for SSH traffic). SSL termination also occurs at the Reverse Proxy side. Communication betwwen the Reverse Proxy and the other containers within the Docker Network is in HTTP. This architecture allows other containers to focus utilizing compute resources on serving content/data instead of encrytping and decrypting data.

##### ```frontend gitlab-fe```

This section creates a listener/frontend called ```gitlab-fe```. It listens on ports 80 and 443 on all interfaces. HAProxy forwards the traffic to the ```backend gitlab-be```. The server at this backend is the gitlab container, which listens on port 80.
The ```http-request redirect scheme https unless { ssl_fc }``` directive redirects client HTTP requests to HTTPS if communication is not already taking place using the secure HTTPS protocol.
The ```ssl crt /usr/local/etc/haproxy/certs/ssl.pem``` directive tells HAProxy where to look for the SSL certificate for the secure HTTPS communication with the client.

> Note: Instead of hard-coding the IP addresses of the backend servers, we opted to use their container names. HAProxy resolves the IP addresses from the Docker DNS server, providing flexibility and facilitating service discovery.

***See image below***

![GitLab Homepage](./MD%20images/GitLab-1.png)

##### ```frontend prometheus-fe```

This section creates a listener/frontend called ```prometheus-fe```,which listens on port 9090 on all interfaces. HAProxy forwards the traffic to the ```backend prometheus-be``` which is also the GitLab container. The bundled prometheus server listens on port 9090.

##### ```frontend grafana-fe```

This section creates a listener/frontend called ```grafana-fe```,which listens on port 3000 on all interfaces. HAProxy forwards the traffic to the ```backend grafana-be```. The Grafana container receives the forwarded requests.

##### ```frontend gitlab-ssh-fe```

This section creates a listener/frontend called ```gitlab-ssh-fe```, which listens on port 2222 on all interfaces for SSH connections. Using a different port for SSH traffic than the standard port 22 for HAProxy is a best practice. The ```mode tcp``` directive sets the mode to TCP (Layer 4 of the OSI model), overriding the ```mode http``` from the default section. HAProxy forwards the traffic to the backend ```gitlab-ssh-be```, where the GitLab container listens on port 22.

> Note: The Docker Host machine listens on port 22, which is mapped to forward traffic from the Docker host port 22 to port 2222 of the HAProxy container. HAProxy then forwards the traffic to the GitLab container on port 22. There is no ```ssl crt``` directive for SSH traffic because ```ssl crt``` is used in Layer 7 (Application layer of the OSI model).

### 2. Node Exporter Integration for Prometheus Metrics

Enabling the Node Exporter within GitLab enhances observability by exposing system-level metrics for monitoring purposes. This addition provides insights into server health, resource utilization, and performance metrics.

***The image below*** shows the targets the Prometheus server will be scraping metrics from including the enabled Node Exporter.

![GitLab Homepage](./MD%20images/GitLab-2.png)

### 3. Grafana for Visualization of Prometheus Metrics

Grafana serves as a powerful tool for visualizing Prometheus metrics, offering customizable dashboards and intuitive data exploration capabilities.

***The image below*** shows a Grafana dashboard visualizing various metrics from the Node Exporter which have been scraped by the Prometheus server.

![Node Exporter Grafana Dashboard](./MD%20images/GitLab-3.png)

***The image below*** shows a Grafana dashboard visualizing various metrics from the Postgres Exporter which have been scraped by the Prometheus server.

![Node Exporter Grafana Dashboard](./MD%20images/GitLab-4.png)

## Conclusion

This repository provides a production-ready GitLab setup with improved performance, scalability, and security through HAProxy, monitoring with Prometheus, and visualization with Grafana. This enhanced configuration allows for efficient load balancing, centralized management, and valuable insights into system health and resource utilization.