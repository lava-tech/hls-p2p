package com.tvie.osmf.p2p.events 
{
	import flash.events.Event;
	
	/**
     * ...
     * @author dista
     */
    public class PeerTestEvent extends Event 
    {
        public static const PEER_TEST:String = "PeerTest";
        public function PeerTestEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
			
        }
        
    }

}