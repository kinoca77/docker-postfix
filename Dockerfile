FROM ubuntu

RUN apt-get update && \
			DEBIAN_FRONTEND=noninteractive apt-get install -y postfix postfix-pcre postfix-mysql postfix-ldap maildrop courier-authlib-mysql busybox && \
			rm -fr /var/lib/apt/lists
RUN mv /etc/maildroprc /etc/postfix/ && \
			ln -s postfix/maildroprc /etc/maildroprc

ADD init.sh /init

CMD ["/init"]
