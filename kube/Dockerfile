FROM gcr.io/google.com/cloudsdktool/cloud-sdk:slim

# Install dig for DNS lookups
RUN apt-get update && apt-get install -y --no-install-recommends dnsutils && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY dynDNS.sh conf .
RUN chmod +x dynDNS.sh

ENTRYPOINT ["bash", "./dynDNS.sh"]
