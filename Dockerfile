############################
# STEP 1 build executable binary
############################
FROM alpine:latest AS builder
ENV RCLONE_VERSION=v1.53.4
WORKDIR /bin/
RUN wget https://github.com/ncw/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip -O ./rclone.zip \ 
	&& unzip ./rclone.zip -d ./ \ 
	&& mv ./rclone-${RCLONE_VERSION}-linux-amd64/rclone ./rclone

############################
# STEP 2 build a small server image
############################
FROM dperson/samba:latest 
# ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/samba.sh"]
ENV BUCKET=rclone
ENV AUTH_USER=rclone
ENV AUTH_PASS=rclone123

RUN apk update \
	&& apk add --no-cache fuse runit \
	&& sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

# cleanup
RUN rm -rf /tmp/* \
	&& rm -rf /var/tmp/* \
	&& rm -rf /var/cache/apk/*

COPY ./rclone.conf /root/.config/rclone/rclone.conf
COPY --from=builder /bin/rclone /rclone
WORKDIR /share

RUN mkdir -p /runit/samba \
	&& file="/runit/samba/run" \
	&& echo '#!/bin/sh -e' >>$file \
	&& echo 'exec /usr/bin/samba.sh -p -u "toby;toby" -s "public;/share" -s "toby private share;/toby-private;no;no;no;toby"' >>$file \
	&& chmod +x $file
RUN mkdir -p /runit/rclone \
	&& file="/runit/rclone/run" \
	&& echo '#!/bin/sh -e' >>$file \
	&& echo 'exec /rclone -v mount minio:samba-download /share --allow-non-empty' >>$file \
	&& chmod +x $file

# Run the server binary.
ENTRYPOINT runsvdir -P /runit
EXPOSE 137/udp 138/udp 139 445
