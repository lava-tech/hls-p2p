package com.tvie.osmf.p2p.tracker 
{
	import flash.events.EventDispatcher;
	
    [Event(name = "PeerList", type = "com.tvie.osmf.p2p.events.TrackerEvent")]
        
	/**
     * ...
     * @author dista
     */
    public class TrackerBase extends EventDispatcher 
    {
        
        public function TrackerBase() 
        {
            
        }
        
        public function getPeers(resourceID:String, size:int):void
        {
            throw Error("override getPeers");
        }
    }

}