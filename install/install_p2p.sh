if [[ "`cat /etc/issue`" == Ubuntu* ]]; then
	apt-get update
	apt-get install git
	apt-get install g++
	apt-get install libssl-dev
	apt-get install lua5.1
	apt-get install liblua5.1-0-dev
	apt-get install unzip
	apt-get install screen
else
	yum update
	yum install git
	yum install gcc-c++
	yum install openssl-devel
	yum install lua-devel
	yum install unzip
	yum install screen	
fi

git clone https://github.com/OpenRTMFP/Cumulus.git
curl http://pocoproject.org/releases/poco-1.4.6/poco-1.4.6p4.tar.gz -o poco.tar.gz
tar -xf poco.tar.gz
curl http://luajit.org/download/LuaJIT-2.0.3.tar.gz -o luajit.tar.gz
tar -xf luajit.tar.gz
(cd LuaJIT-2.0.3; make install)
(cd poco-1.4.6p4; ./configure; make; make install)
(cd Cumulus/CumulusLib; make)
(cd Cumulus/CumulusServer; make)

curl http://nodejs.org/dist/v0.10.28/node-v0.10.28.tar.gz -o node.tar.gz
tar -xf node.tar.gz
(cd node-v0.10.28; ./configure; make; make install)

git clone git://github.com/keplerproject/luarocks.git
(cd luarocks; ./configure; make build; make install)

luarocks install redis-lua

curl http://download.redis.io/releases/redis-2.8.11.tar.gz -o redis.tar.gz
tar -xf redis.tar.gz
(cd cd redis-2.8.11; make; make install)
