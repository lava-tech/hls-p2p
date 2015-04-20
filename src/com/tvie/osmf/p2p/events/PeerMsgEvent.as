package com.tvie.osmf.p2p.events 
{
    import com.tvie.osmf.p2p.peer.Peer;
    import com.tvie.osmf.p2p.peer.PeerMsg;
	import flash.events.Event;
	
	/**
     * ...
     * @author dista
     */
    public class PeerMsgEvent extends Event 
    {
        public static const MSG:String = "Message";
        
        public function PeerMsgEvent(type:String, msg:PeerMsg, peer:Peer, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
			this.msg = msg;
            this.peer = peer;
        }
        
        public var result:String;
        public var msg:PeerMsg;
        public var peer:Peer;
    }

}