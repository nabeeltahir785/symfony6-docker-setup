# Symfony 6.2 with PHP 8.1, Nginx, PostgreSQL and pgAdmin on Docker


This repository provides a Docker configuration for a development environment for Symfony 6.2 with PHP 8.1, Nginx, PostgreSQL and pgAdmin. The setup is fully containerized and can be run on any host that supports Docker.

# Requirements

* Docker
* Docker Compose

# Getting Started

1. Clone this repository to your local machine:

``` https://github.com/nabeeltahir785/explore_symfony_6.2.git ```

2. Navigate to the cloned repository:

``` cd explore_symfony_6.2.git ```

3. Build the Docker containers:

`` docker-compose build ``

4. Start the containers:

`` docker-compose up -d ``

5. Install the dependencies for the Symfony application:

`` docker-compose exec app composer install ``

6. Access the Symfony application in your web browser at `http://localhost:8000`

7. Access pgAdmin at `http://localhost:5050`

# Stopping the Containers

To stop the containers, run the following command:

``docker-compose down``

# Environment Variables
The environment variables used in this setup can be found in the .env.example file. These can be modified as needed to suit your specific requirements.


# Troubleshooting

If you encounter any issues, make sure to check the logs for the relevant containers using the following command:

``docker-compose logs <container-name>``

Replace `<container-name>` with the name of the container you want to inspect.

# Conclusion

This repository provides a convenient and easy way to get started with Symfony 6.2 development, using a fully containerized environment that can run on any host with Docker installed. The setup includes PHP 8.1, Nginx, PostgreSQL, and pgAdmin for database management.