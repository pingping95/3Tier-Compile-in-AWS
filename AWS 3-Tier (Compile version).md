# AWS 3-Tier (Compile version)

[사진들](AWS%203-Tier%20(Compile%20version)%205f39c15c87124248abb7a7759a717d15/%E1%84%89%E1%85%A1%E1%84%8C%E1%85%B5%E1%86%AB%E1%84%83%E1%85%B3%E1%86%AF%209e8c0b50c80e4fb69d39776210a30ca8.md)

[Trouble](AWS%203-Tier%20(Compile%20version)%205f39c15c87124248abb7a7759a717d15/Trouble%202304de3643f84f33aefc0523350b74e5.md)

# 1. 목적, 서버 정보

- Apache - Tomcat - MySQL을 Source로 컴파일하여 설치한다.
- service를 등록하여 systemctl 명령어를 사용할 수 있도록 한다.
- mod_jk 모듈을 사용하여 Apache-Tomcat을 연동하는 방법을 파악한다.
- JDBC Driver를 사용하여 Tomcat-MySQL을 연동해본다.
- MySQL Master - Slave 서버 간의 Replication 연동을 하여 데이터의 가용성을 높인다.

---

### [1] Web Server

- OS : Ubuntu 18.04
- Instance Type : t2.micro
- Apache 2.4.46
- tomcat_connector : 1.2.48

### [2] WAS Server

- Instance Type : t2.micro
- OS : Ubuntu 18.04
- Tomcat : 9.0.41

### [3] MySQL

- Instance Type : t2.micro
- OS : Ubuntu 18.04
- MySQL : 5.7.31

# 2.  Overview

## 3-Tier 아키텍처란?

![Untitled](https://user-images.githubusercontent.com/67780144/106696754-b1a06e80-6620-11eb-9a94-38d6b0f2d241.png)

# 3. 아키텍쳐

![_(7)](https://user-images.githubusercontent.com/67780144/106696727-abaa8d80-6620-11eb-8014-1a71f1fc5b4f.png)

# 4. 인프라 구성 & 사전 준비

## 인프라 구성

[1] **VPC**

**: 사용자가 정의한 논리적으로 분리된 클라우드 네트워크**

[2] **Subnet**

**: VPC 내에서 IPv4 주소가 CIDR 블록에 의해 나눠진 주소 단위**

[3] **Internet Gateway**

**: 인터넷에 연결된 Host ( Public Subnet을 위한 NAT )**

[4] **NAT Gateway**

**: Private Subnet의 인터넷을 향한 Outbound 트래픽 허용 ( IPv4 전용 )**

[5] **Security Group**

**: 인스턴스에 대한 Inbound & Outbound 트래픽 제어 (가상 방화벽)**

[6] **Routing Table**

**: Traffic을 어디로 보내줄 지 설정**

[7] **3-Tier Public Routing Table**

**: 해당 라우팅 테이블을 가진 Subnet들은 IGW로 갈 것을 정의**

[8] **3-Tier Private Routing Table (초기)**

**: 해당 라우팅 테이블을 가진 Subnet들은 NAT로 갈 것을 정의**

[9] **3-Tier Private Routing Table (DB Instance에서 필요한 패키지, 파일 설치 후)**

**: DB 인스턴스가 있는 Subnet은 내부에서만 통신할 것을 정의**

[10] **EC2 Instance**

**: 가상 컴퓨팅 환경**

[11] **Load Balancer**

**: AWS에서 제공하는 부하 분산 장치**

### ssh-key 옮기기 ( Local → Bastion )

- Bastion → web, was, db 인스턴스로 ssh 원격 접속을 하기 위해 ssh key를 옮김

```powershell
scp -i .\3tier-bastion-key.pem .\3tier-web-key.pem ubuntu@<<Bastion IP>>:/home/ubuntu
```

![AWS%203-Tier%20(Compile%20version)%205f39c15c87124248abb7a7759a717d15/Untitled%201.png](AWS%203-Tier%20(Compile%20version)%205f39c15c87124248abb7a7759a717d15/Untitled%201.png)

### Bastion → Web, Was, DB Instance 접속

```bash
### Bastion -> WEB
### 3tier-was-key로 접속시 불허, 3tier-web-key로 접속시 성공
ubuntu@ip-10-0-1-41:~/.ssh$ ssh -i 3tier-was-key.pem ubuntu@10.0.3.168
ubuntu@10.0.3.168: Permission denied (publickey).

ubuntu@ip-10-0-1-41:~/.ssh$ ssh -i 3tier-web-key.pem ubuntu@10.0.3.168
Welcome to Ubuntu 18.04.5 LTS (GNU/Linux 5.4.0-1029-aws x86_64)

### Bastion -> WAS
ubuntu@ip-10-0-1-41:~/.ssh$ ssh -i 3tier-was-key.pem ubuntu@10.0.5.115
The authenticity of host '10.0.5.115 (10.0.5.115)' can't be established.
ECDSA key fingerprint is SHA256:q7eHQcdu530g9oOAkew8cJjnnRtd/P1AezXpWAMxK68.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.0.5.115' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04.5 LTS (GNU/Linux 5.4.0-1029-aws x86_64)

### Bastion -> DB
ubuntu@ip-10-0-1-41:~/.ssh$ ssh -i 3tier-db-key.pem ubuntu@10.0.7.165
The authenticity of host '10.0.7.165 (10.0.7.165)' can't be established.
ECDSA key fingerprint is SHA256:VB2YaUg2m5J6KLv3VCbxo+T51Xvqdfci+BFN0Y+5RtE.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.0.7.165' (ECDSA) to the list of known hosts.
```

### ssh-key 권한 400 변경 (보안 고려)

```powershell
ubuntu@ip-10-0-1-41:~$ chmod 400 *

ubuntu@ip-10-0-1-41:~/.ssh$ ls -al
total 32
drwx------ 2 ubuntu ubuntu 4096 Jan 19 08:31 .
drwxr-xr-x 5 ubuntu ubuntu 4096 Jan 19 08:31 ..
-r-------- 1 ubuntu ubuntu 1704 Jan 19 08:30 3tier-bastion-key.pem
-r-------- 1 ubuntu ubuntu 1700 Jan 19 08:30 3tier-db-key.pem
-r-------- 1 ubuntu ubuntu 1700 Jan 19 08:30 3tier-was-key.pem
-r-------- 1 ubuntu ubuntu 1704 Jan 19 08:30 3tier-web-key.pem
-rw------- 1 ubuntu ubuntu  399 Jan 19 07:59 authorized_keys
-rw-r--r-- 1 ubuntu ubuntu  222 Jan 19 08:26 known_hosts
```

# 5. 인스턴스(web, was, db) 설치

## [1] WEB Server

1. **컴파일 설치를 위해 필요한 패키지 설치**
2. **PCRE, APR, APR-util, HTTPD 소스 파일 받아오기**
3. **소스 파일 환경 설정 ( ./configure )**
4. **소스파일 컴파일 ( make, make install )**
5. **systemd 서비스 파일 생성 및 등록**
6. **Test**

### 1) 필요한 패키지들 설치 목록

```bash
sudo su -

# Install the necessary packages
apt-get update -y
apt-get install build-essential -y
apt-get install libexpat1-dev -y
```

### 2) PCRE, APR, APR-util 설치

```bash
cd /usr/local/src
wget https://ftp.pcre.org/pub/pcre/pcre-$PCRE_VERSION.tar.gz
wget https://downloads.apache.org//apr/apr-$APR_VERSION.tar.gz
wget https://downloads.apache.org//apr/apr-util-$APRUTIL_VERSION.tar.gz
wget https://downloads.apache.org//httpd/httpd-$HTTPD_VERSION.tar.gz

## 1. apr
cd /usr/local/src/apr-$APR_VERSION
./configure --prefix=/usr/local/apr
make; make install

## 2. apr-util
cd /usr/local/src/apr-util-$APRUTIL_VERSION
./configure --prefix=/usr/local/apr-util --with-apr=/usr/local/apr
make; make install

## 3. PCRE
cd /usr/local/src/pcre-$PCRE_VERSION
./configure --prefix=/usr/local/pcre
make; make install

## 4. HTTPD
cd /usr/local/src/httpd-$HTTPD_VERSION
./configure --prefix=/usr/local/apache \
--enable-module=so --enable-rewrite --enable-so \
--with-apr=/usr/local/apr \
--with-apr-util=/usr/local/apr-util \
--with-pcre=/usr/local/pcre \
--enable-mods-shared=all

make; make install
```

### 4) Apache 실행

```bash
## 실행 : httpd -k start
## 종료 : httpd -k stop

/usr/local/apache2.4/bin/httpd -k start

root@ip-10-0-3-171:/usr/local/apache2.4# ./bin/httpd -k restart

root@ip-10-0-3-171:/usr/local/apache2.4# ps -ef | grep httpd
root     31522     1  0 00:41 ?        00:00:00 ./bin/httpd -k start
daemon   31627 31522  0 00:42 ?        00:00:00 ./bin/httpd -k start
daemon   31628 31522  0 00:42 ?        00:00:00 ./bin/httpd -k start
daemon   31629 31522  0 00:42 ?        00:00:00 ./bin/httpd -k start
root     31712  1879  0 00:42 pts/0    00:00:00 grep --color=auto httpd

root@ip-10-0-3-171:/usr/local/apache2.4# netstat -ntpl
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      872/systemd-resolve 
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1184/sshd           
tcp6       0      0 :::22                   :::*                    LISTEN      1184/sshd           
tcp6       0      0 :::80                   :::*                    LISTEN      31522/./bin/httpd

root@ip-10-0-3-171:/usr/local/apache2.4# curl localhost
<html><body><h1>It works!</h1></body></html>
```

### 5) systemd 서비스 파일 생성 및 등록

```bash
vim /usr/lib/systemd/system/httpd.service 
[Unit]
Description=apache 
After=network.target syslog.target
 
[Service] 
Type=forking 
User=root 
Group=root 
ExecStart=/usr/local/apache2.4/bin/apachectl start 
ExecStop=/usr/local/apache2.4/bin/apachectl stop 
RestartSec=10 
Restart=always 

[Install] 
WantedBy=multi-user.target

root@ip-10-0-3-171:/usr/local/apache2.4# systemctl restart httpd

root@ip-10-0-3-171:/usr/local/apache2.4# systemctl status httpd
● httpd.service - apache
   Loaded: loaded (/lib/systemd/system/httpd.service; disabled; vendor preset: enabled)
   Active: active (running) since Mon 2021-01-25 00:47:50 UTC; 1s ago
  Process: 32511 ExecStop=/usr/local/apache2.4/bin/apachectl stop (code=exited, status=0/SUCCESS)
  Process: 32514 ExecStart=/usr/local/apache2.4/bin/apachectl start (code=exited, status=0/SUCCESS)
 Main PID: 32527 (httpd)
    Tasks: 82 (limit: 1140)
   CGroup: /system.slice/httpd.service
           ├─32527 /usr/local/apache2.4/bin/httpd -k start
           ├─32528 /usr/local/apache2.4/bin/httpd -k start
           ├─32529 /usr/local/apache2.4/bin/httpd -k start
           └─32530 /usr/local/apache2.4/bin/httpd -k start

Jan 25 00:47:50 ip-10-0-3-171 systemd[1]: Stopped apache.
Jan 25 00:47:50 ip-10-0-3-171 systemd[1]: Starting apache...
Jan 25 00:47:50 ip-10-0-3-171 systemd[1]: Started apache.

root@ip-10-0-3-171:/usr/local/apache2.4# systemctl stop httpd

root@ip-10-0-3-171:/usr/local/apache2.4# systemctl status httpd
● httpd.service - apache
   Loaded: loaded (/lib/systemd/system/httpd.service; disabled; vendor preset: enabled)
   Active: inactive (dead)

Jan 25 00:47:29 ip-10-0-3-171 systemd[1]: Started apache.
Jan 25 00:47:50 ip-10-0-3-171 systemd[1]: Stopping apache...
Jan 25 00:47:50 ip-10-0-3-171 systemd[1]: Stopped apache.
Jan 25 00:47:50 ip-10-0-3-171 systemd[1]: Starting apache...
Jan 25 00:47:50 ip-10-0-3-171 systemd[1]: Started apache.
Jan 25 00:47:59 ip-10-0-3-171 systemd[1]: Stopping apache...
Jan 25 00:47:59 ip-10-0-3-171 systemd[1]: Stopped apache.
Jan 25 00:47:59 ip-10-0-3-171 systemd[1]: /lib/systemd/system/httpd.service:13: Unknown lvalue 'Umask' in section 'Service'
Jan 25 00:47:59 ip-10-0-3-171 systemd[1]: /lib/systemd/system/httpd.service:13: Unknown lvalue 'Umask' in section 'Service'
Jan 25 00:48:00 ip-10-0-3-171 systemd[1]: /lib/systemd/system/httpd.service:13: Unknown lvalue 'Umask' in section 'Service'
```

## [2] WAS (Web Application Server)

1. **Java Runtime ( JRE 11 ) 설치**
2. **/etc/profile 모든 사용자 대상 환경변수 등록**
3. **Tomcat Group, User 생성**
4. **Apache-Tomcat 설치**
5. **Tomcat 서비스 파일 생성 및 등록**
6. **Test**

### 1) Java Runtime 설치, 환경변수 설정

- jdk 설치

```bash
# sudo su -를 안할 경우 권한 설정을 잘 해주어야 함
sudo su -

sudo apt-get update -y
sudo apt-get install openjdk-11-jre-headless -y
```

- 환경변수 등록
    - /usr/bin/java 경로에 Symbolic Link 경로가 걸려있으므로 실제 경로를 찾아 환경변수를 등록해주어야 한다.
    - 실제 경로를 찾았으면 3가지 (JAVA_HOME, PATH, CLASSPATH)를 등록

```bash
root@ip-10-0-5-115:/home/ubuntu# readlink -f /usr/bin/java
/usr/lib/jvm/java-11-openjdk-amd64/bin/java

## JAVA_HOME, CATALINA_HOME, PATH 환경변수 등록

sudo bash -c 'cat >> /etc/profile' << EOF
# 1.  JAVA_HOME DIR
JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/

# 2. TOMCAT SERVER HOME DIR
CATALINA_HOME=/usr/local/tomcat

# 3. binary
PATH=$PATH:/usr/lib/jvm/java-11-openjdk-amd64/bin

export JAVA_HOME CATALINA_HOME PATH
EOF

## source 명령어로 적용
source /etc/profile

echo $JAVA_HOME
echo $CATALINA_HOME
echo $PATH

root@ip-10-0-5-206:~# java -version
openjdk version "11.0.9.1" 2020-11-04
OpenJDK Runtime Environment (build 11.0.9.1+1-Ubuntu-0ubuntu1.18.04)
OpenJDK 64-Bit Server VM (build 11.0.9.1+1-Ubuntu-0ubuntu1.18.04, mixed mode, sharing)
```

### 2) Tomcat User 생성 & Apache Tomcat 설치

```bash
sudo groupadd tomcat

sudo useradd -s `which nologin | sed -n 1p` -g tomcat -d /usr/local/tomcat tomcat

cd /usr/local/src

sudo wget https://downloads.apache.org/tomcat/tomcat-9/v9.0.41/bin/apache-tomcat-9.0.41.tar.gz

sudo tar -zxvf apache-tomcat-9.0.41.tar.gz

sudo mv apache-tomcat-9.0.41 /usr/local/tomcat
```

### 3) Permission 설정

```bash
cd /usr/local

sudo chmod -R 755 tomcat

sudo chown -R tomcat:tomcat tomcat
```

### 4) Systemd Unit file 설정

```bash
cat << EOF >> /etc/systemd/system/tomcat.service

[Unit]
Description=Apache Tomcat Web Application Container
After=syslog.target network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
ExecStart=/usr/local/tomcat/bin/startup.sh
ExecStop=/usr/local/tomcat/bin/shutdown.sh
SuccessExitStatus=143
Restart=always
RestartSec=10
UMask=0007

[Install]
WantedBy=multi-user.target

EOF

## 대몬 재시작
systemctl daemon-reload 

systemctl restart tomcat

systemctl status tomcat

● tomcat.service - Apache Tomcat Web Application Container
   Loaded: loaded (/etc/systemd/system/tomcat.service; disabled; vendor preset: enabled)
   Active: active (running) since Mon 2021-01-25 01:05:07 UTC; 2s ago
  Process: 4318 ExecStart=/opt/tomcat/bin/startup.sh (code=exited, status=0/SUCCESS)

## netstat -ntlp

Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      882/systemd-resolve 
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1181/sshd           
tcp6       0      0 :::8080                 :::*                    LISTEN      4339/java           
tcp6       0      0 :::22                   :::*                    LISTEN      1181/sshd           
tcp6       0      0 127.0.0.1:8005          :::*                    LISTEN      4339/java
```

### 5) 접속 Test

```bash
## 접속 Test 
curl localhost:8080

<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <title>Apache Tomcat/9.0.41</title>
        <link href="favicon.ico" rel="icon" type="image/x-icon" />
        <link href="tomcat.css" rel="stylesheet" type="text/css" />
    </head>
..
..
..
..
```

## [3] Database (MySQL)

1. **컴파일 설치를 위해 필요한 패키지 설치**
2. **User, Group 생성**
3. **Source 파일 Download 및 압축 해제**
4. **cmake 수행 후 make 빌드**
5. **디렉터리 생성 및 권한 변경**
6. **my.cnf 생성 및 DB 생성 후 초기 설정**
7. **DB 서비스 등록 및 시작**
8. **Test**

### 1) Source Compile 설치를 위해 필요한 Package 설치

```bash
sudo apt install build-essential bison \
gcc g++ libncurses5-dev libxml2-dev openssl \
libssl-dev curl libcurl4-openssl-dev libjpeg-dev \
libpng-dev libfreetype6-dev libsasl2-dev \
autoconf libncurses5-dev libtirpc-dev \
ncurses* cmake-gui cmake -y
```

- cmake : make의 소스관리 문제점을 개선시켜 새롭게 나온 빌드 프레임워크 프로그램

    ( centos 7.x 이상 지원)

- make : 직접 소스를 빌드하는 프로그램 (소스를 빌드하여 기계어로 만들어주는 핵심적인 역할, GNU make 3.75 이상 버전을 강력히 권고)
- ncurses library : 프로그래머가 텍스트 사용자 인터페이스를 터미널 독립 방식으로 기록할 수 있도록 APU를 제공하는 프로그래밍 라이브러리
- boost : 각종 데이터 구조와 알고리즘을 모아둔 C++ 라이브러리

### 2) 유저 및 그룹 생성

- nologin : 유저의 로그인쉘 사용 못하게 함 ( mysql이라는 유저는 mysql 데몬을 실행하기 위한 유저일 뿐, 보안 강화 측면)

```bash
root@ip-10-0-7-218:~# which nologin
/usr/sbin/nologin

root@ip-10-0-7-218:~# useradd -s /usr/sbin/nologin -g mysql mysql
```

### 3) 파일 다운 및 압축 해제

```bash
cd /usr/local/src

wget https://downloads.mysql.com/archives/get/p/23/file/mysql-boost-5.7.31.tar.gz

tar zxvf mysql-boost-5.7.31.tar.gz

cd mysql-5.7.31
```

### 4) cmake 수행

```bash
sudo cmake \
'-DCMAKE_INSTALL_PREFIX=/usr/local/mysql5.7' \
'-DINSTALL_SBINDIR=/usr/local/mysql5.7/bin' \
'-DINSTALL_BINDIR=/usr/local/mysql5.7/bin' \
'-DMYSQL_DATADIR=/usr/local/mysql5.7/data' \
'-DINSTALL_SCRIPTDIR=/usr/local/mysql5.7/bin' \
'-DWITH_INNOBASE_STORAGE_ENGINE=1' \
'-DWITH_PARTITION_STORAGE_ENGINE=1' \
'-DSYSCONFDIR=/usr/local/mysql5.7/etc' \
'-DDEFAULT_CHARSET=utf8mb4' \
'-DDEFAULT_COLLATION=utf8mb4_general_ci' \
'-DWITH_EXTRA_CHARSETS=all' \
'-DENABLED_LOCAL_INFILE=1' \
'-DMYSQL_TCP_PORT=3306' \
'-DMYSQL_UNIX_ADDR=/tmp/mysql.sock' \
'-DCURSES_LIBRARY=/usr/lib/x86_64-linux-gnu/libncurses.so' \
'-DCURSES_INCLUDE_PATH=/usr/include' \
'-DDOWNLOAD_BOOST=1' \
'-DWITH_BOOST=./boost' \
'-DWITH_ARCHIVE_STORAGE_ENGINE=1' \
'-DWITH_BLACKHOLE_STORAGE_ENGINE=1' \
'-DWITH_PERFSCHEMA_STORAGE_ENGINE=1' \
'-DWITH_FEDERATED_STORAGE_ENGINE=1'

make; make install
```

### 5) 디렉터리 생성 및 권한 변경

```bash
cd /usr/local/mysql5.7
mkdir logs tmp data
touch /usr/local/mysql5.7/logs/mysqld_safe.err

cd /usr/local/
chown -R mysql:mysql mysql5.7

## 퍼미션 변경
chown -R mysql:mysql /usr/local/mysql5.7

## 심볼릭 링크 사용
cd /usr/local
ln -s mysql5.7  mysql

## MySQL 라이브러리 등록
root@ip-10-0-7-218:/usr/local# cat /etc/ld.so.conf
include /etc/ld.so.conf.d/*.conf

root@ip-10-0-7-218:/usr/local# ldconfig

include /usr/local/mysql/lib

## 환경변수에 PATH 추가
vi /etc/profile
export PATH=$PATH:/usr/local/mysql/bin

source /etc/profile
```

### 6) my.cnf 생성

```bash
vim /etc/my.cnf

[mysql]
no-auto-rehash
show-warnings
prompt=\u@\h:\d_\R:\m:\\s>
pager="less -n -i -F -X -E"

[mysqld]
server-id=1
port = 3306
bind-address = 0.0.0.0
basedir = /usr/local/mysql
datadir= /usr/local/mysql/data
tmpdir=/usr/local/mysql/data
socket=/tmp/mysql.sock
user=mysql
skip_name_resolve
#timestamp
explicit_defaults_for_timestamp = TRUE

### MyISAM Spectific options
key_buffer_size = 100M

### INNODB Spectific options
default-storage-engine = InnoDB
innodb_buffer_pool_size = 384M

#User Table Datafile
innodb_data_home_dir = /usr/local/mysql/data/
innodb_data_file_path = ib_system:100M:autoextend
innodb_file_per_table=ON
innodb_log_buffer_size = 8M
innodb_log_files_in_group = 3
innodb_log_file_size=200M
innodb_log_files_in_group=4
#innodb_log_group_home_dir = /usr/local/mysql/data/redologs
#innodb_undo_directory = /usr/local/mysql/data/undologs
innodb_undo_tablespaces = 1

### Connection
back_log = 100
max_connections = 1000
max_connect_errors = 1000
wait_timeout= 60

### log
# Error Log
log_error=/usr/local/mysql/logs/mysqld.err
log-output=FILE
general_log=0
slow-query-log=0
long_query_time = 5
# 5 sec
slow_query_log_file = /usr/local/mysql/logs/slow_query.log
pid-file=/usr/local/mysql/tmp/mysqld.pid

###chracterset
character-set-client-handshake=OFF
skip-character-set-client-handshake
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci

[mysqld_safe]
log_error=/usr/local/mysql/logs/mysqld_safe.err
pid-file=/usr/local/mysql/tmp/mysqld.pid
```

### 7) DB 생성 및 ROOT 패스워드 변경

```bash
### 1. DB 생성
cd /usr/local/mysql/bin
./mysqld --initialize --user=mysql --basedir=/usr/local/mysql \
--datadir=/usr/local/mysql/data

root@ip-10-0-7-218:/usr/local/mysql/bin# ls -al /usr/local/mysql/data/
total 931908
drwxr-xr-x  5 mysql mysql      4096 Jan 25 04:21 .
drwxr-xr-x 13 mysql mysql      4096 Jan 25 04:17 ..
-rw-r-----  1 mysql mysql        56 Jan 25 04:21 auto.cnf
-rw-------  1 mysql mysql      1680 Jan 25 04:21 ca-key.pem
-rw-r--r--  1 mysql mysql      1112 Jan 25 04:21 ca.pem
-rw-r--r--  1 mysql mysql      1112 Jan 25 04:21 client-cert.pem
-rw-------  1 mysql mysql      1680 Jan 25 04:21 client-key.pem
-rw-r-----  1 mysql mysql       436 Jan 25 04:21 ib_buffer_pool
-rw-r-----  1 mysql mysql 209715200 Jan 25 04:21 ib_logfile0
-rw-r-----  1 mysql mysql 209715200 Jan 25 04:21 ib_logfile1
-rw-r-----  1 mysql mysql 209715200 Jan 25 04:21 ib_logfile2
-rw-r-----  1 mysql mysql 209715200 Jan 25 04:21 ib_logfile3
-rw-r-----  1 mysql mysql 104857600 Jan 25 04:21 ib_system
drwxr-x---  2 mysql mysql      4096 Jan 25 04:21 mysql
drwxr-x---  2 mysql mysql      4096 Jan 25 04:21 performance_schema
-rw-------  1 mysql mysql      1676 Jan 25 04:21 private_key.pem
-rw-r--r--  1 mysql mysql       452 Jan 25 04:21 public_key.pem
-rw-r--r--  1 mysql mysql      1112 Jan 25 04:21 server-cert.pem
-rw-------  1 mysql mysql      1680 Jan 25 04:21 server-key.pem
drwxr-x---  2 mysql mysql     12288 Jan 25 04:21 sys
-rw-r-----  1 mysql mysql  10485760 Jan 25 04:21 undo001

### 2. MySQL DB 기동
/usr/local/mysql/bin/mysqld_safe &

### 임시 ROOT 패스워드 확인
root@ip-10-0-7-218:/usr/local/mysql/bin# cd ../logs/
root@ip-10-0-7-218:/usr/local/mysql/logs# cat mysqld.err | grep generated
2021-01-25T04:21:28.256460Z 1 [Note] A temporary password is generated for root@localhost: /j0ercg;h9l

/j0ercg;h9lD

###
root@ip-10-0-7-218:/usr/local/mysql/bin# ./mysql -u root -p
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 2
Server version: 5.7.31

Copyright (c) 2000, 2020, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

root@localhost:(none)_04:23:09>

### ALTER USER 'root'@'localhost' IDENTIFIED BY '패스워드';

root@localhost:(none)_04:23:13>ALTER USER 'root'@'localhost' IDENTIFIED BY 'dkagh1.'; 
Query OK, 0 rows affected (0.00 sec)

root@localhost:(none)_04:24:01>COMMIT;
Query OK, 0 rows affected (0.00 sec)

root@localhost:(none)_04:24:03>FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.01 sec)

root@localhost:(none)_04:24:07>exit 
Bye
```

### 8) DB 서비스 등록 및 시작

- DB 중지 (서비스 등록을 위해서)

```bash
root@ip-10-0-7-218:/usr/local/mysql/bin# ./mysqladmin -u root -p shutdown
Enter password: 
2021-01-25T04:24:43.508787Z mysqld_safe mysqld from pid file /usr/local/mysql/tmp/mysqld.pid ended
[1]+  Done                    mysqld_safe
```

- Service 생성

```bash
vim /lib/systemd/system/mysqld.service

[Unit]
Description=Mysql Community Server
After=syslog.target
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/mysql/support-files/mysql.server start
ExecStop=/usr/local/mysql/support-files/mysql.server stop

[Install]
WantedBy=multi-user.target
```

- 대몬 reload 및 DB 시작

```bash
systemctl daemon-reload

systemctl enable mysqld.service

systemctl restart mysqld

root@ip-10-0-7-218:/usr/local/mysql/bin# systemctl status mysqld
● mysqld.service - Mysql Community Server
   Loaded: loaded (/lib/systemd/system/mysqld.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2021-01-25 04:25:36 UTC; 3s ago
  Process: 11302 ExecStart=/usr/local/mysql/support-files/mysql.server start (code=exited, status=0/SUCCESS)
 Main PID: 11322 (mysqld_safe)
    Tasks: 28 (limit: 2348)
   CGroup: /system.slice/mysqld.service
           ├─11322 /bin/sh /usr/local/mysql/bin/mysqld_safe --datadir=/usr/local/mysql/data --pid-file=/usr/local/mysql/tmp/mysql
           └─11882 /usr/local/mysql/bin/mysqld --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data --plugin-dir=/usr/local

Jan 25 04:25:35 ip-10-0-7-218 systemd[1]: Starting Mysql Community Server...
Jan 25 04:25:35 ip-10-0-7-218 mysql.server[11302]: Starting MySQL
Jan 25 04:25:36 ip-10-0-7-218 mysql.server[11302]: . *
Jan 25 04:25:36 ip-10-0-7-218 systemd[1]: Started Mysql Community Server.
```

- test

```bash
root@ip-10-0-7-218:/usr/local/mysql/bin# mysql -u root -p
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 2
Server version: 5.7.31 Source distribution

Copyright (c) 2000, 2020, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

root@localhost:(none)_04:26:14>status
--------------
mysql  Ver 14.14 Distrib 5.7.31, for Linux (x86_64) using  EditLine wrapper

Connection id:		2
Current database:	
Current user:		root@localhost
SSL:			Not in use
Current pager:		less -n -i -F -X -E
Using outfile:		''
Using delimiter:	;
Server version:		5.7.31 Source distribution
Protocol version:	10
Connection:		Localhost via UNIX socket
Server characterset:	utf8mb4
Db     characterset:	utf8mb4
Client characterset:	utf8mb4
Conn.  characterset:	utf8mb4
UNIX socket:		/tmp/mysql.sock
Uptime:			40 sec

Threads: 1  Questions: 6  Slow queries: 0  Opens: 108  Flush tables: 1  Open tables: 101  Queries per second avg: 0.150
--------------
```

---

# 6. Apache - Tomcat 연동

## [1] mod_jk

- 주의사항 : NLB DNS 주소가 길면 workers.properties가 인식을 하지 못한다. NLB 주소는 짧게 유지한다.

### Architecture

![Untitled 2](https://user-images.githubusercontent.com/67780144/106696732-ad745100-6620-11eb-8a59-2aea3ea947f2.png)

### Apache

1. mod_jk 설치

```bash
cd /usr/local/src

wget http://apache.tt.co.kr/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.48-src.tar.gz

tar zxvf tomcat-connectors-1.2.48-src.tar.gz

apt-get install apache2-dev

which apxs
/usr/bin/apxs

cd tomcat-connectors-1.2.48-src/native/

./configure --with-apxs=/usr/bin/apxs

make; make install

mv apache-2.0/mod_jk.so /usr/local/apache2.4/modules/
```

2. Apache 설정 파일 수정

1. httpd.conf에 mod_jk.conf 추가
2. mod_jk.conf 파일 설정
3. [workers.properties](http://workers.properties) 파일 설정
4. [uriworkermap.properties](http://uriworkermap.properties) 파일 설정

```bash
## 1. httpd.conf 수정

root@ip-10-0-3-171:/usr/local/apache2.4/conf# tail httpd.conf 
# Note: The following must must be present to support
#       starting without SSL on platforms with no /dev/random equivalent
#       but a statically compiled-in mod_ssl.
#
<IfModule ssl_module>
SSLRandomSeed startup builtin
SSLRandomSeed connect builtin
</IfModule>

## 맨 아래에 아래 내용 추가!
Include conf/mod_jk.conf

## 2. mod_jk.conf 파일 추가

root@ip-10-0-3-171:/usr/local/apache2.4/conf# cat mod_jk.conf 
LoadModule    jk_module  modules/mod_jk.so

JkWorkersFile conf/workers.properties
JkShmFile     logs/mod_jk.shm
JkLogFile     logs/mod_jk.log
JkLogLevel    info
JKMountFile conf/uriworkermap.properties
JKLogStampFormat "[%a %b %d %H:%M:%s %Y]"
JKRequestLogFormat "%w %V %T"

## 3. workers.properties 파일 추가
root@ip-10-0-3-171:/usr/local/apache2.4/conf# cat workers.properties 
##### workers.properties ##
worker.list=worker1
worker.worker1.type=ajp13
worker.worker1.host=w-lb-c44f0579003043f8.elb.ap-northeast-2.amazonaws.com
worker.worker1.port=8009

## 4. uriworkermap.properties 파일 추가
root@ip-10-0-3-171:/usr/local/apache2.4/conf# cat uriworkermap.properties 
/*=worker1
!/*.html=worker1

root@ip-10-0-3-171:/usr/local/apache2.4/conf# ls
extra  httpd.conf  magic  mime.types  mod_jk.conf  original  uriworkermap.properties  workers.properties
```

3. tomcat 설정 파일 (server.xml) 수정

- mod_jk protocol port 개방

```bash
vim server.xml

..
..

<Connector protocol="AJP/1.3"
               address="0.0.0.0"
               port="8009"
               secretRequired="false"
               URIEncoding="UTF-8"
               redirectPort="8443" />
```

![Untitled 3](https://user-images.githubusercontent.com/67780144/106696734-ad745100-6620-11eb-8030-9ef7a7990a2a.png)

4. Test

- Browser에서 external_alb 출력

![Untitled 4](https://user-images.githubusercontent.com/67780144/106696737-ae0ce780-6620-11eb-99ec-2ffd54981922.png)

- Browser에서 external_alb/index.jsp 출력

![Untitled 5](https://user-images.githubusercontent.com/67780144/106696739-ae0ce780-6620-11eb-8532-4540afc856db.png)

---

### 2) mod_proxy
- mod_proxy는 8080 Port를 통해 연동하는 방법이다.



## [1] MySQL

```java
root@localhost:(none)_00:01:15>CREATE DATABASE test_db default character set utf8; 
Query OK, 1 row affected (0.00 sec)

root@localhost:(none)_00:03:59>CREATE USER 'hello_user'@'%' IDENTIFIED BY 'passw0rd!'; 
Query OK, 0 rows affected (0.00 sec)

root@localhost:(none)_00:04:34>GRANT ALL PRIVILEGES ON test_db.* to 'hello_user'@'%' IDENTIFIED BY 'passw0rd!'; 
Query OK, 0 rows affected, 1 warning (0.00 sec)

Warning (Code 1287): Using GRANT statement to modify existing user's properties other than privileges is deprecated and will be removed in future release. Use ALTER USER statement for this operation.
root@localhost:(none)_00:05:09>FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.01 sec)

root@localhost:(none)_00:05:42>exit 
Bye
ubuntu@ip-10-0-7-113:~$ mysql -u hello_user -p
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 9
Server version: 5.7.31-log Source distribution

Copyright (c) 2000, 2020, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

hello_user@localhost:(none)_00:05:54>SHOW DATABASES;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| test_db            |
+--------------------+
2 rows in set (0.00 sec)

hello_user@localhost:(none)_00:07:03>USE test_db; 
Database changed
hello_user@localhost:test_db_00:07:15>SHOW TABLES;
Empty set (0.00 sec)

hello_user@localhost:test_db_00:07:23>CREATE TABLE test_table(name varchar(30)); 
Query OK, 0 rows affected (0.02 sec)

hello_user@localhost:test_db_00:07:44>insert into test_table values('test_value'); 
Query OK, 1 row affected (0.01 sec)

hello_user@localhost:test_db_00:08:16>select * from test_table; 
+------------+
| name       |
+------------+
| test_value |
+------------+
1 row in set (0.00 sec)

hello_user@localhost:test_db_00:08:22>commit;
Query OK, 0 rows affected (0.00 sec)
```

## [2] Tomcat

- JDBC Driver 설치

```bash
cd /usr/local/src

wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.48.tar.gz

## tar 압축 해제
tar xzf mysql-connector-java-5.1.48.tar.gz

cd /usr/local/src/mysql-connector-java-5.1.48

cp mysql-connector-java-5.1.48-bin.jar $JAVA_HOME/lib

vim /etc/profile

..
..
## CLASSPATH 추가
CLASSPATH=$JAVA_HOME/lib/mysql-connector-java-5.1.48-bin.jar

export JAVA_HOME CATALINA_HOME PATH CLASSPATH

source /etc/profile
```

![Untitled 8](https://user-images.githubusercontent.com/67780144/106696746-af3e1480-6620-11eb-9a35-0a03fee222d5.png)

- test.jsp 생성

```java
<%@ page language="java" contentType="text/html; charset=UTF-8"
       pageEncoding="UTF-8" import="java.sql.*"%>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>DB Connection Test</title>
</head>
<body>
       <%
              String DB_URL = "jdbc:mysql://10.0.7.113:3306/test_db";
              String DB_USER = "hello_user";
              String DB_PASSWORD = "passw0rd!";
              Connection conn;
              Statement stmt;
              PreparedStatement ps;
              ResultSet rs;
              try {
                     Class.forName("com.mysql.jdbc.Driver");
                     conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
                     stmt = conn.createStatement();

                    /* SQL 처리 코드 추가 부분 */

                     conn.close();
                     out.println("MySQL JDBC Driver Connection Test Success!!!");

/* 예외 처리  */
              } catch (Exception e) {
                     out.println(e.getMessage());
              }
       %>
</body>
</html>
```

![Untitled 9](https://user-images.githubusercontent.com/67780144/106696747-afd6ab00-6620-11eb-909a-8a5c7cca0bcc.png)

![Untitled 10](https://user-images.githubusercontent.com/67780144/106696748-afd6ab00-6620-11eb-968d-24abe6dcfbd8.png)

# 8. MySQL Replication

## [1] Architecture

- Master 서버의 장애가 생겼을 경우 Slave 서버로 변경하여 사용할 수 있다.

## [2] 원리

1. Master : my.cnf에서 server-id를 1로 설정
2. Master : mysql 데몬을 재시작 후 Master 서버 정보를 확인한다.
3. Slave : my.cnf에서 server-id를 2로 설정, 복제할 db를 설정 (모든 db를 복제할 경우 지정해주지 않아도 된다.)
4. Slave : Master의 Endpoint, Port, user의 password, user_id, ip, log_position, log_file 등을 기입해준다.
5. MySQL 데몬을 재시작 후 start slave; 명령어를 기입해준다.
6. 복제가 되는지 확인한다.

## [3] 설정 방법

### 1) Master DB 설정

- mysql -u root -p로 접속 후 db 생성, 계정 생성, 권한 부여, ..

```bash
## DB 생성
mysql> create database repl_db default character set utf8;

## 계정생성
mysql> create user user1@'%' identified by 'test123';

##권한부여
mysql> grant all privileges on repl_db.* to user1@'%' identified by 'test123';

## 리플리케이션 계정생성
mysql> grant replication slave on *.* to 'repl_user'@'%' identified by 'test456'

## my.cnf 설정

vi /etc/my.cnf
[mysqld]
log-bin=mysql-bin
server-id=1
..

## mysqld 재시작
systemctl restart mysqld

## Master 정보 확인
root@localhost:(none)_07:36:13>show master status;
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000003 |      154 |              |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
1 row in set (0.00 sec)

## File : MySQL 로그파일
## Position : 로그 파일내 읽을 위치
## Binlog_Do_DB : 바이너리(Binary)로그 파일(변경된 이벤트 정보가 쌓이는 파일)
## Binlog_Ignore_DB : 복제 제외 정보
```

### 2) Slave 서버

- DB 생성

```bash
## mysql -u root -p로 접속
## DB 생성
mysql> create database repl_db default character set utf8;

## 계정 생성
mysql> create user user1@'%' identified by 'test123';

## 권한 부여
mysql> grant all privileges on repl_db.* to user1@'%' identified by 'test123';

## my.cnf 설정
# vi /etc/my.cnf

[mysqld]
server-id=2
replicate-do-db='repl_db'

## Master 서버로 연결하기 위한 설정
## mysql -u root -p로 접속

mysql> stop slave;

mysql> change master to
master_host='10.0.7.113',
master_user='repl_user',
master_password='test456',
master_log_file='mysql-bin.000003',
master_log_pos=154;

mysql> start slave;

# MASTER_HOST : Mster 서버 IP 입력
# MASTER_USER : 리플리케이션 ID
# MASTER_PASSWORD : 리플리케이션 PW
# MASTER_LOG_FILE : MASTER STATUS 로그파일명
# MASTER_LOG_POS : MASTER STATUS에서 position 값

# Slave_IO_State, Slave_IO_Running, Slave_SQL_Running이
# 아래와 같이 떠야 정상이다.
mysql> show slave status\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 10.0.7.113
                  Master_User: repl_user
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000003
          Read_Master_Log_Pos: 154
               Relay_Log_File: ip-10-0-8-237-relay-bin.000003
                Relay_Log_Pos: 320
        Relay_Master_Log_File: mysql-bin.000003
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB: repl_db
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table:
..
..
..

## mysql 재시작

systemctl restart mysqld
```

- Test
- Master에서 repl_db로 접속하여 tables를 확인 후 student_db를 생성한다.

    후에 show tables; 를 해봤을 때 student_db가 있음을 확인할 수 있다.

```bash
root@localhost:(none)_07:36:20>use repl_db;
Database changed
root@localhost:repl_db_07:40:02>show tables;
Empty set (0.00 sec)

root@localhost:repl_db_07:40:04>CREATE TABLE `student_tb` (
    ->     `sno` int(11) NOT NULL,
    ->     `name` char(10) DEFAULT NULL,
    ->     `det` char(20) DEFAULT NULL,
    ->     `addr` char(80) DEFAULT NULL,
    ->     `tel` char(20) DEFAULT NULL,
    ->     PRIMARY KEY (`sno`)
    -> ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
Query OK, 0 rows affected (0.03 sec)

root@localhost:repl_db_07:40:06>show tables;
+-------------------+
| Tables_in_repl_db |
+-------------------+
| student_tb        |
+-------------------+
1 row in set (0.01 sec)
```

- Slave에서 repl_db;에 접속하여 처음에 tables를 조회했을 때 아무것도 없지만 Master에서 table을 생성한 이후 성공적으로 복제가 된 것을 확인할 수 있다.

```bash
root@localhost:(none)_07:39:23>use repl_db;
Database changed
root@localhost:repl_db_07:39:49>show tables;
Empty set (0.00 sec)

root@localhost:repl_db_07:39:50>show tables;
+-------------------+
| Tables_in_repl_db |
+-------------------+
| student_tb        |
+-------------------+
1 row in set (0.00 sec)
```

- Master의 Bin Log File 혹은 Position 값이 바뀌는 경우

    SHOW MASTER STATUS; 로 바뀐 값을 확인한다.

![Untitled 11](https://user-images.githubusercontent.com/67780144/106696749-b06f4180-6620-11eb-9ab9-ec971afa630d.png)

- SLAVE에 접속하여 바뀐 값들을 수정해준다.

```python
> stop slave;

> change master to
master_host='10.0.7.113',
master_user='repl_user',
master_password='test456',
master_log_file='mysql-bin.000008',
master_log_pos=154;

> start slave;
```

![Untitled 12](https://user-images.githubusercontent.com/67780144/106696750-b06f4180-6620-11eb-97ef-182bab1091ba.png)

- Master의 Bin_log 파일 or Position 값이 수정될 경우

```python
mysql> stop slave; 

mysql> change master to \
master_host='10.0.7.113', \
master_user='repl_user', \
master_password='test456', \
master_log_file='mysql-bin.000003', \
master_log_pos=154;

mysql> start slave;
```

- Slave_IO_State가 Waiting for master to send event로 바뀌게 된다.

![Untitled 13](https://user-images.githubusercontent.com/67780144/106696752-b107d800-6620-11eb-9b60-0ff7f908a7a4.png)
