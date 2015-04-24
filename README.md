# hls-p2p
Flash OSMF based hybrid cdn&amp;p2p hls solution. Currently it support LIVE hls. 
Flash support rtmfp protocal, we use that to deliver video&audio data in p2p&cdn hybrid way.

NOTE: Please take some time to READ this file.

# how it works
We use https://github.com/denivip/osmf-hls-plugin to enable hls support. Use that as a base, we developed the p2p part.

Normally, for hls protocal, client download m3u8 first, then download ts; In our p2p solution, client download m3u8 from
server first, then download ts and m3u8 from server or other peers.

We developed a algorithm for LIVE hls P2P.

The algorithm is like this:
* for a single ts file, if we download it from peer, we download it from more than one peer
* we establish a p2p topology at first.
* data is pushed from one peer to others
* if one peer exits, downstream will know that after a while, and will PING the exited peer, 
  if PING fails, it will retry to establising a new topology. In the process of rebuilding the
  new topology, data will be downloaded from server.
* peer is considered as stable if it can be added to other peer's topology.
* m3u8 is small, it will be downloaded only from one peer.

Server part:
  * P2P need a server to support rtmfp. we use https://github.com/OpenRTMFP/Cumulus.
    Cumulus support lua, we can add peer id to redis using lua script.
  * we also use redis to store peer ids.
  * a nodejs http service for peer to find other peers' id.

Client part:
  * we implement a `P2PLoader`, which will replace the original `HTTPStreamDownloader` in osmf-hls-plugin

# Install
  * our test server is CentOS 6.2, you can `bash install/install_p2p.sh` to install required server software.
  * The IDE we used to develope our flash code is 'FlashDevelop'

# Run and test
Server:
  * start redis
  * copy "cumulus/main.lua" to "Cumulus/CumulusServer/www" folder and start CumulusServer.
    For how to set config for CumulusServer, refer to https://github.com/OpenRTMFP/Cumulus/wiki/Installation#configurations
  * copy "server/remote_log" to any folder, under remote_log, run `npm install`, then `node index.js`
  * you also need a media server to stream HLS(such as FMS, Wowza, or Lava Media Server 4(trochilus) if you interested).
    note: Lava Media Server 4 is not a open source project now.

Client:
  * Build the binary. Note: because we use osmf source code directly, you need to remove default osmf lib in you computer
    before building it.
  * Change config in bin/index.html
  ```
  change the ip of your server in bin/index.html, such as "115.29.205.140"
  ```
  some config value and their meanings are as follows:
  ```
  # the url of LIVE hls stream, it MUST be live and single stream
  # it should only contain ts file, and MUST NOT contain another m3u8 file
  m3u8_url: "http://211.103.128.226:8080/live/tvie/xray/pad.m3u8",
  # the rtmfp url
  rtmfp_url: "rtmfp://115.29.205.140:19350/app",
  # the url we will get peers information
  http_tracker: "http://115.29.205.140:5000/get_peers",
  # send log to that url
  remote_log_base_url: "http://115.29.205.140:5000/remote_log",
  # how many peers we will use to download data
  rtmfp_url_peers: 2,
  # leave it as it is
  index_rtmfp_url: "",
  # leave it as it is
  index_rtmfp_url_peers: 1,
  # the server ip and port from where we download m3u8 and ts.
  # if you do not know how it works, set it as the same as `m3u8_url`
  source_servers: ["211.103.128.226:8080"]
  ```
 
  * put bin/* under a web server(such as nginx).
  * visit `bin/index.html` in your browser

# Data
In Cumulus, we will add peer informations to redis.
You can get the peer informations in redis with following command

* List all p2p instance.
```
127.0.0.1:6379 > SMEMBERS cumulus_app
```

* For one p2p instance, get all connected peers' id. for example: if I want to get peers of a p2p instance called "app"
```
127.0.0.1:6379> LLEN app
(integer) 1
127.0.0.1:6379> LRANGE app 0 1
1) "c39e1de52e704279ecb6800bdb4c20006059d6b600b8abd08941a4119dc4250b"
```

* For some debug reason, if you want to clear all peers of a p2p instance called "app", you can do
```
127.0.0.1:6379> LTRIM app 0 0
```

# peer - server protocal
* Flash client connect Cumulus using RTMFP protocal. Flash client will get a `peerID`(a unique id), and in `main.lua`,
  we save client `peerID` to redis.
* Flash client send http request to `remote_log` service to find other peer ids, so that it can connect other peer.
* If user close the `index.html` page, the page will send `disconnect` event to `remote_log`, `remote_log` will remove that
  peer's id from redis.(We need to do this because Flash in chrome will not send disconnect event to Cumulus server)

# peers protocal
* First, we need to create two way session between two peer, from each side it can send msg. We call it "Create Session"
* We call one ts file as CHUNK. A CHUNK may contain more than one PIECE. We download one PIECE of CHUNK from different peer.
* After we have connect ENOUGH peers, we send them HAS_CHUNK_REQ(ts_url) msg to query if we can download PIECE from them.
* After enough peers send back us 'HAS_CHUNK_RESP(yes)', We send 'GET_PIECE_REQ(url, piece_id)' to qualified peers.
* After we got some data of a CHUNK, we feed it to player.
* If we do not get the CHUNK at required time, we will query if the peer still alive, if not, we call it "P2P Failed".
* If we are in "P2P Failed", we will shift from "P2P mode" to "CDN mode".
* If we are in "CDN mode", we will try to shift to "P2P mode" at intervals
