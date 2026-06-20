FROM ubuntu:22.04
RUN apt-get update -qq && apt-get install -y wget unzip ca-certificates -qq
WORKDIR /app
COPY start.sh .
RUN chmod +x start.sh
CMD ["./start.sh"]
