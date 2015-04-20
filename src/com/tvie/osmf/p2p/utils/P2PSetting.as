package com.tvie.osmf.p2p.utils 
{
	/**
     * ...
     * @author dista
     */
    public class P2PSetting 
    {
        
        public function P2PSetting() 
        {
            
        }
        
        /**
         * timeout of sending msg
         */
        public static const MSG_TIMEOUT:int = 30000;
        
        /**
         * if true, do not do any process util it reaches LIMIT_DOWNLOAD_PROGRESS_EVENT_BYTES
         */
        public static const LIMIT_DOWNLOAD_PROGRESS_EVENT:Boolean = true;
        
        /**
         * buffer downloaded data until it exceeds LIMIT_DOWNLOAD_PROGRESS_EVENT_BYTES
         */
        public static const LIMIT_DOWNLOAD_PROGRESS_EVENT_BYTES:int = 260000;
        
        /**
         * how many pieces we need to sperate from one chunk,
         * and get these pieces from each peer
         * 
         * this will be set by user
         */
        public static var CHUNK_PEERS_COUNT:int = 10;
        
        /**
         * get_peers will return at largest (CHUNK_PEERS_COUNT * CHUNK_PEERS_COUNT_FACTOR) peers
         */
        public static var CHUNK_PEERS_COUNT_FACTOR:Number = 1.5;
        
        /**
         * The total number of inbound and outbound peer connections that this instance of Flash Player or Adobe AIR allows.
         * set to a very big value, do not limit now
         */
        public static const SESSION_MAX_PEER_CONNECTIONS:int = 65535;
        
        /**
         * the number of peers we can push piece to them
         */
        public static const OUT_PEER_LIMIT:int = 50;
        
        /**
         * time of waiting repair topology
         */
        public static const REPAIR_TOPO_TIMEOUT:int = 30000;
        
        /**
         * if now - peer.connection_time < REPAIR_SECOND_CHANGE_TIME, repair will use that peer again
         */
        public static const REPAIR_SECOND_CHANGE_TIME:int = 4000;
        
        /**
         * the time P2PLoader will try to change to p2pnetwork again
         */
        public static const CHANGE_TO_P2P_RETRY_TIME:int = 30000;
        
        /**
         * time out when connect to peer
         */
        public static const PEER_CONNECT_TIMEOUT:int = 10000;
        
        /**
         * the max transfer time spent in push piece
         * 
         * this will be set by parsing m3u8
         */
        public static var MAX_TRANSFER_TIME_FOR_PIECE:int = 30000;
        
        /**
         * the max time can be used to get first chunk from p2p network
         * 
         * this will be set by parsing m3u8
         */
        public static var GET_CHUNK_FIRST_TIMEOUT:int = 30000;
        
        /**
         * MAX count of chunk which chunkcache will keep
         */
        public static const MAX_CHUNK_COUNT:int = 60;
        
        /**
         * after timeout stage2, the max time we will wait before repairing chunk
         */
        public static const DESPERATE_TIMEOUT:int = 5000;
        
        /**
         * time duration of reporting speed, output peer count infomation.
         */
        public static const REPORT_STATE_DURATION:int = 120000;
        
        /**
         * version of p2p plugin
         */
        public static const VERSION:String = "0.4.8";
        
        /**
         * time of waiting connecting rtmfp server
         */
        public static const SESSION_CONNECTION_TIMEOUT:int = 15000;
        
        /**
         * chunk's duration, in milliseconds
         */
        public static var CHUNK_DURATION:int = 5000;
    }

}