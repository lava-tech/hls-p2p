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
