package com.tvie.osmf.p2p.events 
{
	import flash.events.Event;
	
	/**
     * ...
     * @author dista
     */
    public class PublishPointEvent extends Event 
    {
        public static const NEW_PEER_CONNECTED:String = "NewPeerConnected";
        public static const PUBLISH_START:String = "PublishStart";
        
        public function PublishPointEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
			
        }
        
        public var peerID:String;
    }

}