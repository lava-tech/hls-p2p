# hls-p2p
Flash OSMF based hybrid cdn&amp;p2p hls solution. Currently it support LIVE hls. 
Flash support rtmfp protocal, we use that to deliver video&audio data in p2p&cdn hybrid way.

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
  * copy "cumulus/main.lua" to "Cumulus/CumulusServer/www" and start CumulusServer
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
  
  * open multiply browser tab for `bin/index.html`
