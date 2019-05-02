FROM postgres

# RUN localedef -i pl_PL -c -f UTF-8 -A /usr/share/locale/locale.alias pl_PL.UTF-8
# ENV LANG pl_PL.utf8
# ENV LC_MESSAGES=en_US.utf8'

# COPY ./sql /docker-entrypoint-initdb.d
COPY create-multiple-databases.sh /docker-entrypoint-initdb.d/
