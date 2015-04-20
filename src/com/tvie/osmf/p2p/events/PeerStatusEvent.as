package com.tvie.osmf.p2p.events 
{
    import com.tvie.osmf.p2p.peer.Peer;
    import com.tvie.osmf.p2p.peer.PeerMsg;
	import flash.events.Event;
    import flash.utils.ByteArray;
	
	/**
     * ...
     * @author dista
     */
    public class PeerStatusEvent extends Event 
    {
        public static const PEER_STATUS:String = "PeerStatus";
        
        public static const CONNECT_OK:String = "PeerStatus.Connect.Ok";
        public static const CONNECT_ERROR:String = "PeerStatus.Connect.Error";
        public static const CONNECT_TIMEOUT:String = "PeerStatus.Connect.Timeout";
        public static const RESP_MSG_SEND:String = "PeerStatus.RespMsg.Send";
        
        public function PeerStatusEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false,
                                  target:Peer = null, code:String = null
                                 ) 
        {
            super(type, bubbles, cancelable);
			
            this.peer = target;
            this.code = code;
        }
        
        public var peer:Peer;
        public var code:String;
        public var msg:PeerMsg;
    }

}