# hls-p2p
Flash OSMF based hybrid cdn&amp;p2p hls solution. Currently it support LIVE hls. 
Flash support rtmfp protocal, we use that to deliver video&audio data in p2p&cdn hybrid way.

# how it works
We use https://github.com/denivip/osmf-hls-plugin to enable hls support. Use that as a base, we developed the p2p part.

Normally, for hls protocal, client download m3u8 first, then download ts; In our p2p solution, client download m3u8 from
server first, then download ts and m3u8 from server or other peers.

We developed a algorithm for LIVE hls P2P.
