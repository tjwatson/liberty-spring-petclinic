FROM ibmjava:8-sfj-alpine as staging

# Install unzip; needed to unzip Open Liberty
#RUN apt-get update \
#    && apt-get install -y --no-install-recommends unzip \
#    && rm -rf /var/lib/apt/lists/*

# Install Open Liberty
ENV LIBERTY_SHA c326227f903f073c3f574588bdcc1e3aa5d9bf05
ENV LIBERTY_URL https://public.dhe.ibm.com/ibmdl/export/pub/software/openliberty/runtime/nightly/2018-06-28_0619/openliberty-all-20180628-0500.zip

ENV SPRING_BOOT_VERSION 2.0

RUN wget -q "$LIBERTY_URL" -U UA-Open-Liberty-Docker -O /tmp/wlp.zip \
   && echo "$LIBERTY_SHA  /tmp/wlp.zip" > /tmp/wlp.zip.sha1 \
   && sha1sum -c /tmp/wlp.zip.sha1 \
   && mkdir /opt/ol \
   && unzip -q /tmp/wlp.zip -d /opt/ol \
   && rm /tmp/wlp.zip \
   && rm /tmp/wlp.zip.sha1 \
   && mkdir -p /opt/ol/wlp/usr/servers/springServer/ \
   && echo spring.boot.version="$SPRING_BOOT_VERSION" > /opt/ol/wlp/usr/servers/springServer/bootstrap.properties \
   && echo \
'<?xml version="1.0" encoding="UTF-8"?> \
<server description="Spring Boot Server"> \
  <featureManager> \
    <feature>jsp-2.3</feature> \
    <feature>transportSecurity-1.0</feature> \
    <feature>websocket-1.1</feature> \
    <feature>springBoot-${spring.boot.version}</feature> \
  </featureManager> \
  <httpEndpoint id="defaultHttpEndpoint" host="*" httpPort="9080" httpsPort="9443" /> \
  <include location="appconfig.xml"/> \
</server>' > /opt/ol/wlp/usr/servers/springServer/server.xml \
   && /opt/ol/wlp/bin/server start springServer \
   && /opt/ol/wlp/bin/server stop springServer \
   && echo \
'<?xml version="1.0" encoding="UTF-8"?> \
<server description="Spring Boot application config"> \
  <springBootApplication location="app" name="Spring Boot application" /> \
</server>' > /opt/ol/wlp/usr/servers/springServer/appconfig.xml

# Stage the fat JAR
COPY target/petclinic.jar /staging/myFatApp.jar

# Thin the fat application; stage the thin app output and the library cache
RUN /opt/ol/wlp/bin/springBootUtility thin \
 --sourceAppPath=/staging/myFatApp.jar \
 --targetThinAppPath=/staging/myThinApp.jar \
 --targetLibCachePath=/staging/lib.index.cache

# unzip thin app to avoid cache changes for new JAR
RUN mkdir /staging/myThinApp \
   && unzip -q /staging/myThinApp.jar -d /staging/myThinApp

# Final stage, only copying the liberty installation (includes primed caches)
# and the lib.index.cache and thin application
FROM ibmjava:8-sfj-alpine

COPY --from=staging /opt/ol/wlp /opt/ol/wlp

COPY --from=staging /staging/lib.index.cache /opt/ol/wlp/usr/shared/resources/lib.index.cache

COPY --from=staging /staging/myThinApp /opt/ol/wlp/usr/servers/springServer/apps/app

EXPOSE 9080

CMD ["/opt/ol/wlp/bin/server", "run", "springServer"]
