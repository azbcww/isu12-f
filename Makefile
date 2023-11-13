#:set noexpandtab
#:retab! スペースの数

#書き換え必要
SERVICE_NAME = isuconquest

SQL_CNF_DIR = /etc/mysql/conf.d
NGINX_CONF_DIR = /etc/nginx/conf.d

MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=isucon
MYSQL_DBNAME=isucondition
MYSQL_PASS=isucon

#書き換え不必要
GIT_EMAIL = 46641274+azbcww@users.noreply.github.com
GIT_USERNAME = isucon
GIT_REPO = 

WEBHOOK_URL=https://discord.com/api/webhooks/1152289240005222442/u8fs7v0oXC4HmAEs_2sFas5GW7FTqYu5QZULUE0CFpnv6qxGrCfM1v3m31WjcPj6UzYo

LOGIN_KEY = ~/.ssh/PISCON11/id_ed25519

########################
########################

#書き換え後 ~/
.PHONY: setup
setup: git-setup git-repo install-tools github-config vimrc apt-update

.PHONY: setup-local
setup-local: scp-github-key scp-Makefile

.PHONY: git-setup
git-setup:
	git config --global user.email "$(GIT_EMAIL)"
	git config --global user.name "$(GIT_USERNAME)"

.PHONY: git-repo
git-repo:
	git init && \
	git remote add origin $(GIT_REPO)

.PHONY: apt-update
apt-update:
	sudo apt update

.PHONY: install-go
install-go:
	sudo apt install -y golang-go

.PHONY: install-alp
install-alp:
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.tar.gz
	tar -zxvf alp_linux_amd64.tar.gz
	sudo mv alp /usr/local/bin/
	rm alp_linux_amd64.tar.gz

.PHONY: install-pt-query-digest
install-pt-query-digest:
	sudo apt install percona-toolkit -y

.PHONY: install-tools
install-tools:apt-update install-alp install-pt-query-digest

.PHONY: setup-tmux
setup-tmux:
	@{ \
	echo set-option -g mouse on; \
	echo bind-key -n WheelUpPane if-shell -F -t = \"#{mouse_any_flag}\" \"send-keys -M\" \"if -Ft= \'#{pane_in_mode}\' \'send-keys -M\' \'select-pane -t=";" copy-mode -e";" send-keys -M\'\"; \
	echo bind-key -n WheelDownPane select-pane -t= \\";" send-keys -M; \
	echo setw -g mode-keys vi; \
	} > ~/.tmux.conf
	@tmux source-file ~/.tmux.conf

.PHONY: pre-bench
before-bench: trun-access trun-slow

.PHONY: send-data
send-data: alp send-alp pt send-pt

#練習環境
.PHONY: bench
bench: trun-access trun-slow
	export ISUXBENCH_TARGET=127.0.0.1 && \
	./bin/benchmarker --stage=prod --request-timeout=10s --initialize-request-timeout=60s

.PHONY: alp
alp:
	@sudo cat /var/log/nginx/access.log | alp json --sort sum -r -q --qs-ignore-values -o "count,1xx, 2xx, 3xx, 4xx, 5xx, method, uri, min, max, sum, avg" -m '/api/organizer/[0-9a-z\/]+, /api/player/[0-9a-z\/]+, /api/admin/[0-9a-z\/]+' > /tmp/alp.txt

.PHONY: send-alp
send-alp:
	-@curl -X POST -F txt=@/tmp/alp.txt $(WEBHOOK_URL) -s -o /dev/null

.PHONY: alp-body
alp-body:
	@sudo cat /var/log/nginx/access.log | alp json --sort sum -r -q --qs-ignore-values -o "count, method, min_body, max_body, sum_body, avg_body" -m '/api/organizer/[0-9a-z\/]+, /api/player/[0-9a-z\/]+, /api/admin/[0-9a-z\/]+' > /tmp/alp-body.txt

.PHONY: send-alp-body
send-alp-body:
	-@curl -X POST -F txt=@/tmp/alp-body.txt $(WEBHOOK_URL) -s -o /dev/null

.PHONY: pt
pt:
	@sudo pt-query-digest /var/log/mysql/mysql-slow.log > /tmp/pt-query-digest.txt

.PHONY: send-pt
send-pt:
	-@curl -X POST -F txt=@/tmp/pt-query-digest.txt $(WEBHOOK_URL) -s -o /dev/null

.PHONY: trun-access
trun-access:
	@sudo truncate /var/log/nginx/access.log -s 0

.PHONY: trun-slow
trun-slow:
	@sudo truncate /var/log/mysql/mysql-slow.log -s 0

.PHONY: sql
sql:
	@mysql -u$(MYSQL_USER) -p$(MYSQL_PASS)

.PHONY: scp-github-%
scp-github-%:
	@scp -i $(LOGIN_KEY) ~/.ssh/id_ed25519 isucon@${@:scp-github-%=%}:~/.ssh/

.PHONY: scp-github-key
scp-github-key:
	@scp -i $(LOGIN_KEY) ~/.ssh/id_ed25519 isucon@${AWS}:~/.ssh/

.PHONY: scp-Makefile
scp-Makefile:
	@scp -i $(LOGIN_KEY) ~/workspace/Makefile isucon@${AWS}:~/

.PHONY: github-config
github-config:
	@{ \
	echo "Host github github.com"; \
	echo "	HostName github.com"; \
	echo "	IdentityFile ~/.ssh/id_ed25519"; \
	echo "	User git"; \
	} >> ~/.ssh/config

.PHONY: vimrc
vimrc:
	@{ \
	echo set tabstop=4; \
	echo set shiftwidth=4; \
	} > ~/.vimrc

.PHONY: isu
isu:
	@ssh -i $(LOGIN_KEY) isucon@${AWS}

.PHONY: ubu
ubu:
	@ssh -i $(LOGIN_KEY) ubuntu@${AWS}

.PHONY: authorized_keys
authorized_keys:
	@sudo cp /home/ubuntu/.ssh/authorized_keys /home/isucon/.ssh/
	@sudo chown isucon:isucon /home/isucon/.ssh/authorized_keys

.PHONY: restart
restart:
	@sudo systemctl restart mysql.service
	@sudo systemctl restart nginx.service

.PHONY: disable-%
disable-%:
	sudo systemctl stop ${@:disable-%=%}
	sudo systemctl disable ${@:disable-%=%}

.PHONY: disable-for-app-nginx
disable-for-app-nginx: disable-mysql disable-cron disable-ufw disable-atd
	sudo ufw disable

.PHONY: disable-for-app
disable-for-app: disable-mysql disable-nginx disable-cron disable-ufw disable-atd
	sudo ufw disable

.PHONY: disable-for-db
disable-for-db: disable-$(SERVICE_NAME) disable-nginx disable-cron disable-ufw disable-atd
	sudo ufw disable

.PHONY: setup-mysql-for-pt
setup-mysql-for-pt:
	mkdir -p s1/etc
	sudo cp -r /etc/mysql s1/etc/
	sudo chown isucon -R s1/etc/mysql
	{ \
	echo [mysqld];\
	echo slow_query_log=1;\
	echo slow_query_log_file="/var/log/mysql/mysql-slow.log";\
	echo long_query_time=0;\
	} >> s1$(SQL_CNF_DIR)/my.cnf
	sudo cp s1$(SQL_CNF_DIR)/my.cnf $(SQL_CNF_DIR)/my.cnf

.PHONY: setup-nginx-for-alp
setup-nginx-for-alp:
	mkdir -p s1/etc
	sudo cp -r /etc/nginx s1/etc/
	sudo chown isucon -R s1/etc/nginx
	{ \
	echo log_format json escape=json \'{\"time\":\""$$"time_local\",\';\
	echo '\t'\'\"host\":\""$$"remote_addr\",\';\
	echo '\t'\'\"forwardedfor\":\""$$"http_x_forwarded_for\",\';\
	echo '\t'\'\"req\":\""$$"request\",\';\
	echo '\t'\'\"status\":\""$$"status\",\';\
	echo '\t'\'\"method\":\""$$"request_method\",\';\
	echo '\t'\'\"uri\":\""$$"request_uri\",\';\
	echo '\t'\'\"body_bytes\":\""$$"body_bytes_sent\",\';\
	echo '\t'\'\"referer\":\""$$"http_referer\",\';\
	echo '\t'\'\"ua\":\""$$"http_user_agent\",\';\
	echo '\t'\'\"request_time\":\""$$"request_time\",\';\
	echo '\t'\'\"cache\":\""$$"upstream_http_x_cache\",\';\
	echo '\t'\'\"runtime\":\""$$"upstream_http_x_runtime\",\';\
	echo '\t'\'\"response_time\":\""$$"upstream_response_time\",\';\
	echo '\t'\'\"vhost\":\""$$"host\"}\'";";\
	echo "";\
	echo access_log  /var/log/nginx/access.log json;\
	} >> s1$(NGINX_CONF_DIR)/my.conf
	sudo cp s1$(NGINX_CONF_DIR)/my.conf $(NGINX_CONF_DIR)/my.conf

.PHONY: build
build:
	cd webapp/go && \
	go build -o $(SERVICE_NAME);\
	sudo systemctl restart $(SERVICE_NAME).go.service
