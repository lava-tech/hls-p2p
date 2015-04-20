package com.tvie.osmf.p2p.data 
{
	/**
     * ...
     * @author dista
     */
    public class ChunkState 
    {
        public static const INIT:String = "init";
        public static const LOADING_FROM_PEERS:String = "LoadingFromPeers";
        public static const LOADING_FROM_SOURCE:String = "LoadingFromSource";
        public static const LOAD_FROM_SOURCE_DONE:String = "LoadFromSourceDone";
        public static const LOAD_FROM_PEERS_DONE:String = "LoadFromPeersDone";
        public static const LOADING_FROM_HYBRID:String = "LoadingFromHybrid";
        public static const LOAD_FROM_HYBRID_DONE:String = "LoadFromHybridDone";
        
        public function ChunkState() 
        {
            
        }
        
    }

}