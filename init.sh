#!/bin/bash

if [[ -n "$SYSLOG_ADDR" ]]; then
	syslogd_args=( -R "$SYSLOG_ADDR" -L )
fi
busybox syslogd -S -O /dev/fd/3 "${syslogd_args[@]}" 3>&1

function wait-pid {
	while [[ -e /proc/$1/status ]]; do sleep 1; done
}

while read filename; do
	# kubernetes doesn't allow '/' in secret volumes, so use '---' as '/'.
	filename_dest="${filename//---/\/}"
	if [[ "$filename_dest" == *"/"* ]]; then
		mkdir -p "${filename_dest%/*}"
	fi
	rm -rf /etc/postfix/"$filename_dest"
	ln -s /etc/postfix.vol/"$filename" /etc/postfix/"$filename_dest"
done < <(find /etc/postfix.vol -mindepth 1 -maxdepth 1 -printf '%P\n' 2>/dev/null)

if [[ -e "/etc/courier/authdaemonrc" ]]; then
	mkdir -p /var/run/courier/authdaemon
	/usr/lib/courier/courier-authlib/authdaemond > >(logger -t couier-authlib) 2> >(logger -p error -t courier-authlib) &
fi

if [[ ! -d /var/spool/postfix/virtual ]]; then
	mkdir -p /var/spool/postfix/virtual
	chown mail:mail /var/spool/postfix/virtual
fi

while read mapfile; do
	if [[ -e "$mapfile.db" ]] && [[ "$mapfile.db" -nt "$mapfile" ]]; then
		continue
	fi
	postmap "$mapfile"
done < <(postconf | grep -oP 'hash:\K[^\s,]+')

postfix start || exit $?
pid="$(grep -oP '\d+' /var/spool/postfix/pid/master.pid)"
trap "postfix stop; wait-pid $pid" EXIT
trap exit SIGSEGV SIGTERM SIGINT SIGQUIT

wait-pid $pid
