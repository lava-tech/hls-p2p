package com.tvie.osmf.p2p.events 
{
    import com.tvie.osmf.p2p.peer.Peer;
    import com.tvie.osmf.p2p.peer.PeerMsg;
	import flash.events.Event;
	
	/**
     * ...
     * @author dista
     */
    public class PeerMsgErrorEvent extends Event 
    {
        public static const ERROR:String = "PeerMsgError";
        
        public static const TIMEOUT:String = "PeerMsgError.Timeout";
        
        public function PeerMsgErrorEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
			
        }
        
        public var code:String;
        public var msg:PeerMsg;
        public var peer:Peer;
    }

}