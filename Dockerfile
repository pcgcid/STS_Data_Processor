FROM rocker/r-ver:4.4.1

RUN R --quiet -e "install.packages('remotes', repos = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest')"
RUN R --quiet -e "remotes::install_github('rstudio/renv')"

RUN R -e "utils::install.packages('renv')"

# Install system dependencies, including fontconfig and freetype2
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    zlib1g-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libudunits2-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
RUN mkdir /app
WORKDIR /app

COPY renv.lock .
RUN R --quiet -e "renv::restore()"


# Copy the R script and necessary data files to the container
COPY sts_script.R /app/
COPY sts_col_names.rds /app/

WORKDIR /tmp
RUN chmod +x '/app/sts_script.R'

# Install required R packages
#RUN Rscript -e "install.packages(c('tidyverse', 'readxl'), repos='http://cran.rstudio.com/')"

# Set the default command to run the R script
ENTRYPOINT ["/app/sts_script.R"]