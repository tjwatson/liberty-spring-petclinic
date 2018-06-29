FROM tjwatson/ol:springboot2 as staging

# Stage the fat JAR
COPY target/petclinic.jar /staging/myFatApp.jar

# Thin the fat application; stage the thin app output and the library cache
RUN springBootUtility thin \
 --sourceAppPath=/staging/myFatApp.jar \
 --targetThinAppPath=/staging/myThinApp.jar \
 --targetLibCachePath=/staging/lib.index.cache

# Final stage, only copying the liberty installation (includes primed caches)
# and the lib.index.cache and thin application
FROM tjwatson/ol:springboot2

COPY --from=staging /staging/lib.index.cache /lib.index.cache

COPY --from=staging /staging/myThinApp.jar /config/dropins/spring/myThinApp.jar

