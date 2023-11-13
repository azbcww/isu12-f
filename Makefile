#:set noexpandtab
#:retab! スペースの数

#expot AWS=


GIT_EMAIL = 46641274+azbcww@users.noreply.github.com
GIT_USERNAME = azbcww
GIT_REPO = git@github.com:azbcww/isucon12-qualify.git

MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=isucon
MYSQL_DBNAME=isucondition
MYSQL_PASS=isucon

.PHONY: setup
setup: git-setup install-tools github-config vimrc

.PHONY: setup-local
setup-local: scp-github-key scp-Makefile

.PHONY: setup-ubuntu
setup-ubuntu: authorized-keys

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

.PHONY: install-alp
install-alp:
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.tar.gz
	tar -zxvf alp_linux_amd64.tar.gz
	sudo mv alp /usr/local/bin/

.PHONY: install-pt-query-digest
install-pt-query-digest:
	sudo apt install percona-toolkit -y

.PHONY: install-tools
install-tools:apt-update install-alp install-pt-query-digest

.PHONY: bench
bench: trun-access trun-slow
	@cd bench && \
	./bench -target-addr 127.0.0.1:443

.PHONY: alp
alp:
	@sudo cat /var/log/nginx/access.log | alp json --sort sum -r -q --qs-ignore-values

.PHONY: pt
pt:
	@sudo pt-query-digest /var/log/mysql/mysql-slow.log

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
	@scp -i ~/.ssh/isucon.pem ~/.ssh/id_ed25519 isucon@${@:scp-github-%=%}:~/.ssh/

.PHONY: scp-github-key
scp-github-key:
	@scp -i ~/.ssh/isucon.pem ~/.ssh/id_ed25519 isucon@${AWS}:~/.ssh/

.PHONY: scp-Makefile
scp-Makefile:
	@scp -i ~/.ssh/isucon.pem ~/workspace/Makefile isucon@${AWS}:~/

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

.PHONY: isu-%
isu-%:
	
	@ssh -i ~/.ssh/isucon.pem isucon@${@:isu-%=%}

.PHONY: ubu-%
ubu-%:
	@ssh -i ~/.ssh/isucon.pem ubuntu@${@:ubu-%=%}

.PHONY: isu
isu:
	@ssh -i ~/.ssh/isucon.pem isucon@${AWS}

.PHONY: ubu
ubu:
	@ssh -i ~/.ssh/isucon.pem ubuntu@${AWS}

.PHONY: authorized_keys
authorized_keys:
	@sudo cp /home/ubuntu/.ssh/authorized_keys /home/isucon/.ssh/
	@sudo chown isucon:isucon /home/isucon/.ssh/authorized_keys

.PHONY: restart
restart:
	@sudo systemctl restart mysql.service
	@sudo systemctl restart nginx.service
