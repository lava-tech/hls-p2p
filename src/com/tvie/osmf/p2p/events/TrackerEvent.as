package com.tvie.osmf.p2p.events 
{
	import flash.events.Event;
	
	/**
     * ...
     * @author dista
     */
    public class TrackerEvent extends Event 
    {
        public static const PEER_LIST:String = "PeerList";
        
        public function TrackerEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
        }
        
        public var peers:Vector.<String>;
    }

}