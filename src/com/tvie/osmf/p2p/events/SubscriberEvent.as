package com.tvie.osmf.p2p.events 
{
	import flash.events.Event;
	
	/**
     * ...
     * @author dista
     */
    public class SubscriberEvent extends Event 
    {
        public static const ON_STATUS:String = "Status";
        
        public static const SUBSCRIBE_OK:String = "Subscribe.Ok";
        public static const SUBSCRIBE_ERROR:String = "Subscribe.Error";
        
        public function SubscriberEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
			
        }
        
        public var code:String;
    }

}