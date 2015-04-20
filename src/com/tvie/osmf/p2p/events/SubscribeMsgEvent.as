package com.tvie.osmf.p2p.events 
{
	import flash.events.Event;
	
	/**
     * ...
     * @author dista
     */
    public class SubscribeMsgEvent extends Event 
    {
        public static const ON_MSG:String = "Message";
        
        public function SubscribeMsgEvent(type:String, msg:Object, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
			
            this.msg = msg;
        }
        
        public var msg:Object;
    }

}