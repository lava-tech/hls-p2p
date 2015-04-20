package com.tvie.osmf.p2p.events 
{
    import com.tvie.osmf.p2p.peer.Peer;
	import flash.events.Event;
	
	/**
     * ...
     * @author dista
     */
    public class P2PNetworkEvent extends Event 
    {
        public static const STATUS:String = "Status";
        
        public static const GET_PEERS_OK:String = "P2PNetwork.GetPeers.OK";
        public static const GET_PEERS_ERROR:String = "P2PNetwork.GetPeers.Error";
        public static const GET_CHUNK_ERROR:String = "P2PNetwork.GetChunk.Error";
        public static const GET_PEER_LIST_OK:String = "P2PNetwork.GetPeerList.Ok";
        public static const DROP_PEER_LISTENER:String = "P2PNetwork.DropPeerListener";
        public static const CONNECT_ACTIVE_PEERS_DONE:String = "P2PNetwork.ConnectActivePeers.Done";
        public static const CHANGE_TO_P2P_OK:String = "P2PNetwork.ChangeToP2P.OK";
        public static const CHANGE_TO_P2P_ERROR:String = "P2PNetwork.ChangeToP2P.Error";
        public static const NETWORK_ERROR:String = "P2PNetwork.Network.Error";
        public static const IDX_NOT_READY:String = "P2PNetwork.IDX.NotReady";
        public static const IDX_READY:String = "P2PNetwork.IDX.Ready";
        
        public function P2PNetworkEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
			
        }
        
        public var code:String;
        public var peer:Peer;
    }

}